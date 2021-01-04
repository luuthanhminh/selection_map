import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

abstract class PartialViewModelWidget<T, R> extends Widget {

  const PartialViewModelWidget({Key key}) : super(key: key);

  @protected
  Widget build(BuildContext context, R data);

  @protected
  R buildPartialData(T viewModel);

  @override
  _DataProviderElement<T, R> createElement() => _DataProviderElement<T, R>(this);
}

class _DataProviderElement<T, R> extends ComponentElement {
  _DataProviderElement(PartialViewModelWidget widget) : super(widget);

  @override
  PartialViewModelWidget get widget => super.widget;

  @override
  Widget build() {
    return Selector<T, R>(builder: (_, data, __) => widget.build(this, data), selector: (_, vm) =>  widget.buildPartialData(vm));

  }


  @override
  void update(PartialViewModelWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    rebuild();
  }
}