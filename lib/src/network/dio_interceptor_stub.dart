// Stub file for when Dio is not available
// This prevents compilation errors when the package is used without Dio

class LogHoodDioInterceptor {
  LogHoodDioInterceptor({
    dynamic logger,
    bool logRequestBody = true,
    bool logResponseBody = true,
    bool logHeaders = true,
    int maxBodyLength = 1000,
  });
}