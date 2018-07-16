import 'dart:async';
import 'package:redux/redux.dart';
import 'package:redux_optimistic_thunk/src/redux_optimistic_manager_base.dart';

Middleware<Optimistic<State>> optimisticThunk<State>() {
    OptimisticManager manager;

    return (Store<Optimistic<State>> store, dynamic action, NextDispatcher next) {
        manager ??= new OptimisticManager(store);

        assert(identical(manager.store, store));

        if (action is! OptimisticThunkAction) {
            next(manager.postAction(action));
            return;
        }

        bool isActualThunkReturned = false;
        bool isOptimisticThunkReturned = false;
        bool isOptimisticStateRollbacked = false;

        final int transactionId = action.transactionId;

        void actualDispatch([dynamic action]) {
            // Rollback optimistic state on first async dispatch
            if (isActualThunkReturned && !isOptimisticStateRollbacked) {
                isOptimisticStateRollbacked = true;
                manager.rollback(transactionId, next);
            }

            // Allow call `dispatch` without argument to rollback optimistic actions
            if (action != null) {
                next(manager.postAction(action));
            }
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
    };
}

class OptimisticThunkAction {
  final _actualThunk;
  final _optimisticThunk;

  final int transactionId = identityHashCode(new Object());
  
  OptimisticThunkAction(Future<Null> actualThunk(void dispatch([dynamic action])), void optimisticThunk(dispatch(dynamic action)))
      : _actualThunk = actualThunk, _optimisticThunk = optimisticThunk;

  dynamic actualThunk(dynamic action) => _actualThunk(action);
  void optimisticThunk(dynamic action) => _optimisticThunk(action);
}