// Conditional export for Dio interceptor
// Uses the real interceptor if Dio is available, otherwise uses a stub

export 'dio_interceptor.dart' 
    if (dart.library.io) 'dio_interceptor.dart'
    if (dart.library.html) 'dio_interceptor.dart';