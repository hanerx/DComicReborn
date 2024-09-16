import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class EntityBase{
  dynamic convertValue<T>(dynamic value){
    try {
      switch(T){
        case String:
          return value.toString();
        case bool:
          return value=='1';
        case int:
          return int.parse(value);
        case double:
          return double.parse(value);
        case Map:
          return jsonDecode(value);
        default:
          return value;
      }
    }catch (e, s) {
      FirebaseCrashlytics.instance.recordError(e, s,reason: 'ValueConvert Failed: (Value= $value, Type= $T)');
    }
    return null;
  }

  String? convertFromValue(dynamic value){
    try{
      switch(value.runtimeType){
        case bool:
          return value?'1':'0';
        default:
          if(value is Map){
            return jsonEncode(value);
          }
          if(value is Enum){
            return value.index.toString();
          }
          return value.toString();
      }
    }catch(e,s){
      FirebaseCrashlytics.instance.recordError(e, s,reason: 'ValueConvert Failed: (Value= $value, Type= ${value.runtimeType})');
    }
    return null;
  }
}