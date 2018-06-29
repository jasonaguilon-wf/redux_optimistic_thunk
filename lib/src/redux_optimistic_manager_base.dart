import 'package:redux/redux.dart' show Reducer, Store;

class Optimistic<State> {
  final State state;
  final bool isPending;

  Optimistic(this.state, [this.isPending=false]);
}

Reducer<Optimistic<State>> createOptimisticReducer<State>(Reducer<State> nextReducer) {
  return (Optimistic<State> inputState, dynamic action) {
    if (action is OptimisticRollback) return action.payload;
    
    // When `nextReducer` is created from `combineReducers`,
    // the `optimistic` mark we added to state will raise a warning in console,
    // so we should remove the mark before `nextReducer` is called
    final Optimistic<State> previous = _extractOptimisticMark(inputState);
    final bool optimistic = previous.isPending;
    final State previousState = previous.state;
    final State nextState = nextReducer(previousState, action);

    // If `nextReducer` returns `null` or non object, we should not add optimistic mark on it
    if (nextState == null) return null;

    return recoverOptimisticMark(
        inputState,
        previous.state,
        nextState,
        action is OptimisticMark ? true : optimistic
    );
  };
}

Optimistic<State> recoverOptimisticMark<State>(Optimistic<State> inputState, State previousState,
    State nextState, bool isPending) {
  if (inputState.isPending == isPending && previousState == nextState) {
    return inputState;
  }

  // TODO: fix this hack around mutable state.
  return new Optimistic(nextState is List ? nextState.toList() : nextState, isPending);
//  return new Optimistic(nextState, isPending);
}

Optimistic<State> _extractOptimisticMark<State>(Optimistic<State> state) {
    if (state == null || state.isPending) {
        return new Optimistic(state.state);
    }

    return new Optimistic(state.state, state.isPending);
}

abstract class OptimisticAction {}

class OptimisticRollback<State> implements OptimisticAction {
  final Optimistic<State> payload;
  OptimisticRollback(this.payload);
}

class OptimisticMark implements OptimisticAction {}

class OptimisticManager<State> {
  final Store<Optimistic<State>> store;
  Optimistic<State> savePoint = null;
  List<_DispatchedAction> dispatchedActions = <_DispatchedAction>[];

  OptimisticManager(this.store);

  dynamic postAction(action, [transactionId]) {
    if (_isKnownActionType(action)) return action;

    if (transactionId == null) {
      _saveActionOnDemand(action);
    }
    else {
      _createSavePointOnDemand();
      _saveActionOnDemand(action, transactionId);
      _markStateOptimisticOnDemand();
    }

    return action;
  }

  void rollback(transactionId, [void replay(dynamic action)]) {
    replay ??= store.dispatch;

    if (transactionId == null) {
      throw new ArgumentError.notNull('transactionId');
    }

    if (savePoint == null) {
      return;
    }

    // Force state to match save point
    store.dispatch(new OptimisticRollback(savePoint));

    Optimistic<State> newSavePoint = null;
    List<_DispatchedAction> newDispatchedActions = <_DispatchedAction>[];

    // Because we will dispatch previously saved actions, make a copy here to prevent infinite loops
    for (var savedAction in dispatchedActions.toList()) {
      // Ignore all optimistic actions produced by the same transaction
      if (savedAction.transactionId == transactionId) {
        continue;
      }

      final bool isOptimisticAction = savedAction.transactionId != null;

      // The next save point should be the first time an optimistic action is dispatched,
      // so any actions earlier than new save point should be safe to discard
      if (newSavePoint == null && isOptimisticAction) {
        newSavePoint = store.state;
      }

      if (newSavePoint != null) {
        newDispatchedActions.add(savedAction);
      }

      // Still mark state to optimistic if an optimistic action occurs
      if (isOptimisticAction && !store.state.isPending) {
        store.dispatch(new OptimisticMark());
      }

      // Apply remaining action to make state up to time,
      // here we just need to apply all middlewares **after** redux-optimistic-manager,
      // so use `next` instead of global `dispatch`
      replay(savedAction.value);
    }

    savePoint = newSavePoint;
    dispatchedActions = newDispatchedActions;
  }

  void _saveActionOnDemand(value, [transactionId]) {
    if (savePoint == null) return;
    dispatchedActions.add(new _DispatchedAction(value, transactionId));
  }

  void _markStateOptimisticOnDemand() {
    if (!store.state.isPending) {
      store.dispatch(new OptimisticMark());
    }
  }

  void _createSavePointOnDemand() {
    if (savePoint != null) return;
    savePoint = store.state;
  }
}

bool _isKnownActionType(action) => action is OptimisticAction;

class _DispatchedAction {
  final value;
  final transactionId;

  _DispatchedAction(this.value, this.transactionId);
}


