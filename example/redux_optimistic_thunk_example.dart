import 'dart:async';
import 'package:redux/redux.dart' show NextDispatcher, Store;

import 'package:redux_optimistic_thunk/redux_optimistic_thunk.dart' show Optimistic, OptimisticAction, OptimisticMark, OptimisticRollback, OptimisticThunkAction, createOptimisticReducer, optimisticThunk;

class Push {
  final String value;

  Push(this.value);
}

List<String> reducer(List<String> state, dynamic action) {
  if (action is Push) {
    return state..toList()..add(action.value);
  }
  return state;
}

void logger(Store<Optimistic<List<String>>> store, dynamic action, NextDispatcher next) {
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
  print('$prefix ${prints.join(' -> ')}');
}

final store = new Store<Optimistic<List<String>>>(createOptimisticReducer(reducer), initialState: new Optimistic(<String>[]), middleware: [optimisticThunk, logger]);

main() async {
  var slow = new OptimisticThunkAction(
          (void dispatch(dynamic action)) async {
        dispatch(new Push('slow actual 1'));
        dispatch(new Push('slow actual 2'));

        await new Future.delayed(new Duration(milliseconds: 500));

        dispatch(new Push('slow actual 3'));
        dispatch(new Push('slow actual 4'));
      },
          (void dispatch(dynamic action)) {
        dispatch(new Push('slow optimi 1'));
        dispatch(new Push('slow optimi 2'));
      }
  );

  var fast = new OptimisticThunkAction(
          (void dispatch(dynamic action)) async {
        dispatch(new Push('fast actual 1'));
        dispatch(new Push('fast actual 2'));

        await new Future.delayed(new Duration(milliseconds: 200));

        dispatch(new Push('fast actual 3'));
        dispatch(new Push('fast actual 4'));
      },
          (void dispatch(dynamic action)) {
        dispatch(new Push('fast optimi 1'));
        dispatch(new Push('fast optimi 2'));
      }
  );

  store.dispatch(slow);
  store.dispatch(fast);
}
