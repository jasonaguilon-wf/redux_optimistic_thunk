import 'dart:async' show Future;
import 'package:redux/redux.dart' show Middleware, NextDispatcher, Store;

import 'package:redux_optimistic_thunk/redux_optimistic_thunk.dart'
    show Optimistic, OptimisticAction, OptimisticMark, OptimisticRollback, OptimisticThunkAction, createOptimisticReducer, optimisticThunk;

class Push {
  final String value;

  Push(this.value);

  @override
  String toString() => 'Push(value: "$value")';
}

List<String> reducer(List<String> state, dynamic action) {
  if (action is Push) {
    return state
      ..toList()
      ..add(action.value);
  }
  return state;
}

Middleware<Optimistic<List<String>>> logger() {
  DateTime start;

  return (Store<Optimistic<List<String>>> store, dynamic action, NextDispatcher next) {
    var now = new DateTime.now();
    start ??= now;
    var diff = now.difference(start);

    if (!(action is Push || action is OptimisticAction)) {
      next(action);
      return;
    }

    next(action);

    var prints = store.state.state.map((value) => value.contains('optimi') ? '($value)' : '_${value}_');
    var prefix = () {
      if (action is OptimisticRollback) {
        return '  (rollback)';
      }
      else if (action is OptimisticMark) {
        return '      (mark)';
      }
      else {
        return store.state.isPending ? '(optimistic)' : '    (actual)';
      }
    }();
    print('$diff $prefix ${prints.join(' -> ')}');
  };
}

final store = new Store<Optimistic<List<String>>>(
    createOptimisticReducer(reducer), initialState: new Optimistic(<String>[]),
    middleware: [optimisticThunk(), logger()]);

main() async {
  var slow = new OptimisticThunkAction(
          (void dispatch([dynamic action])) async {
        await new Future.delayed(new Duration(milliseconds: 5000));
        dispatch(new Push('actual 1'));
      },
          (void dispatch(dynamic action)) {
        dispatch(new Push('optimi 1'));
      }
  );

  var error = new OptimisticThunkAction(
          (dispatch([dynamic action])) async {
        await new Future.delayed(new Duration(milliseconds: 10000));
        dispatch(); // on error, dispatch no action to allow optimistic state to rollback.
      },
          (void dispatch(dynamic action)) {
        dispatch(new Push('optimi 2'));
      }
  );

  store.dispatch(slow);
  store.dispatch(error);
}
