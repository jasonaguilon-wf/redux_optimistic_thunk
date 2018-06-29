import 'dart:async';
import 'package:redux/redux.dart' show NextDispatcher, Store;

import 'package:redux_optimistic_thunk/redux_optimistic_manager.dart' show Optimistic, OptimisticAction, OptimisticManager, OptimisticMark, OptimisticRollback, createOptimisticReducer;

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

final store = new Store<Optimistic<List<String>>>(createOptimisticReducer(reducer), initialState: new Optimistic(<String>[]), middleware: [logger]);

final manager = new OptimisticManager<List<String>>(store);

main() async {

  slow() async {
    var transactionId = identityHashCode(new Object());

    store.dispatch(manager.postAction(new Push('slow actual 1')));

    store.dispatch(manager.postAction(new Push('slow actual 2')));

    store.dispatch(manager.postAction(new Push('slow optimi 1'), transactionId));

    store.dispatch(manager.postAction(new Push('slow optimi 2'), transactionId));

    await new Future.delayed(new Duration(milliseconds: 500));

    manager.rollback(transactionId);

    store.dispatch(manager.postAction(new Push('slow actual 3')));

    store.dispatch(manager.postAction(new Push('slow actual 4')));
  }

  fast() async {
    var transactionId = identityHashCode(new Object());

    store.dispatch(manager.postAction(new Push('fast actual 1')));

    store.dispatch(manager.postAction(new Push('fast actual 2')));

    store.dispatch(manager.postAction(new Push('fast optimi 1'), transactionId));

    store.dispatch(manager.postAction(new Push('fast optimi 2'), transactionId));

    await new Future.delayed(new Duration(milliseconds: 200));

    manager.rollback(transactionId);

    store.dispatch(manager.postAction(new Push('fast actual 3')));

    store.dispatch(manager.postAction(new Push('fast actual 4')));
  }

  await Future.wait([slow(), fast()]);
}
