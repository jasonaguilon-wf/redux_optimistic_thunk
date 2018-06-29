import 'package:redux/redux.dart';
import 'package:redux_optimistic_thunk/src/redux_optimistic_manager_base.dart';

void optimisticThunk<State>(Store<Optimistic<State>> store, dynamic action, NextDispatcher next) {
    var manager = new OptimisticManager(store);

    final int transactionId = identityHashCode(new Object());

    if (action is! OptimisticThunkAction) {
        return next(manager.postAction(action));
    }

    bool isActualThunkReturned = false;
    bool isOptimisticThunkReturned = false;
    bool isOptimisticStateRollbacked = false;

    void actualDispatch(action) {
        // Rollback optimistic state on first async dispatch
        if (isActualThunkReturned && !isOptimisticStateRollbacked) {
            isOptimisticStateRollbacked = true;
            manager.rollback(transactionId, next);
        }

        // Allow call `dispatch` without argument to rollback optimistic actions
        next(manager.postAction(action));
    };

    void optimisticDispatch(action) {
        if (isOptimisticThunkReturned) {
            throw new ArgumentError.value(action, 'action', 'Optimistic thunk must be a sync function');
        }

        return next(manager.postAction(action, transactionId));
    };

    // First call actual thunk to ensure all sync actions are flushed
    action.actualThunk(actualDispatch);
    isActualThunkReturned = true;
    // Then call optimistic thunk to create optimistic state
    action.optimisticThunk(optimisticDispatch);
    isOptimisticThunkReturned = true;
}

class OptimisticThunkAction {
  final _actualThunk;
  final _optimisticThunk;

  OptimisticThunkAction(void actualThunk(dynamic action), void optimisticThunk(dynamic action))
      : _actualThunk = actualThunk, _optimisticThunk = optimisticThunk;

  dynamic actualThunk(dynamic action) => _actualThunk(action);
  void optimisticThunk(dynamic action) => _optimisticThunk(action);
}