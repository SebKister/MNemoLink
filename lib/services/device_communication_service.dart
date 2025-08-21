// Platform-conditional export for DeviceCommunicationService
// Web gets stub implementation, IO (including mobile and desktop) gets desktop implementation
// We'll handle mobile platforms at runtime within the desktop implementation

export 'device_communication_service_desktop.dart'
    if (dart.library.html) 'device_communication_service_stub.dart';