#include "windows_usage_channel.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <tlhelp32.h>

#include <cstdint>
#include <string>

namespace {

constexpr char kChannelName[] = "focustrace/windows_usage";
constexpr char kGetActiveWindowInfo[] = "getActiveWindowInfo";

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }

  int size = ::WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                   static_cast<int>(value.size()), nullptr, 0,
                                   nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }

  std::string result(size, '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), size,
                        nullptr, nullptr);
  return result;
}

std::string GetWindowTitle(HWND window) {
  int length = ::GetWindowTextLengthW(window);
  if (length <= 0) {
    return std::string();
  }

  std::wstring title(static_cast<size_t>(length) + 1, L'\0');
  int copied = ::GetWindowTextW(window, title.data(), length + 1);
  if (copied <= 0) {
    return std::string();
  }

  title.resize(static_cast<size_t>(copied));
  return WideToUtf8(title);
}

std::wstring BaseNameFromPath(const std::wstring& path) {
  size_t separator = path.find_last_of(L"\\/");
  if (separator == std::wstring::npos) {
    return path;
  }
  return path.substr(separator + 1);
}

std::wstring GetProcessNameFromSnapshot(DWORD process_id) {
  HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return std::wstring();
  }

  PROCESSENTRY32W entry = {};
  entry.dwSize = sizeof(PROCESSENTRY32W);
  if (::Process32FirstW(snapshot, &entry)) {
    do {
      if (entry.th32ProcessID == process_id) {
        ::CloseHandle(snapshot);
        return entry.szExeFile;
      }
    } while (::Process32NextW(snapshot, &entry));
  }

  ::CloseHandle(snapshot);
  return std::wstring();
}

std::wstring GetProcessImagePath(DWORD process_id) {
  HANDLE process =
      ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (process == nullptr) {
    return std::wstring();
  }

  std::wstring path(MAX_PATH, L'\0');
  DWORD size = static_cast<DWORD>(path.size());
  if (!::QueryFullProcessImageNameW(process, 0, path.data(), &size)) {
    ::CloseHandle(process);
    return std::wstring();
  }

  ::CloseHandle(process);
  path.resize(size);
  return path;
}

double GetIdleSeconds() {
  LASTINPUTINFO last_input = {};
  last_input.cbSize = sizeof(LASTINPUTINFO);
  if (!::GetLastInputInfo(&last_input)) {
    return 0.0;
  }

  DWORD elapsed = ::GetTickCount() - last_input.dwTime;
  return static_cast<double>(elapsed) / 1000.0;
}

flutter::EncodableValue GetActiveWindowInfo() {
  HWND foreground_window = ::GetForegroundWindow();
  if (foreground_window == nullptr) {
    return flutter::EncodableMap{
        {flutter::EncodableValue("hasWindow"), flutter::EncodableValue(false)},
        {flutter::EncodableValue("idleSeconds"),
         flutter::EncodableValue(GetIdleSeconds())},
    };
  }

  DWORD process_id = 0;
  ::GetWindowThreadProcessId(foreground_window, &process_id);

  std::wstring process_path = GetProcessImagePath(process_id);
  std::wstring process_name = BaseNameFromPath(process_path);
  if (process_name.empty()) {
    process_name = GetProcessNameFromSnapshot(process_id);
  }

  return flutter::EncodableMap{
      {flutter::EncodableValue("hasWindow"), flutter::EncodableValue(true)},
      {flutter::EncodableValue("windowHandle"),
       flutter::EncodableValue(static_cast<int64_t>(
           reinterpret_cast<intptr_t>(foreground_window)))},
      {flutter::EncodableValue("processId"),
       flutter::EncodableValue(static_cast<int64_t>(process_id))},
      {flutter::EncodableValue("windowTitle"),
       flutter::EncodableValue(GetWindowTitle(foreground_window))},
      {flutter::EncodableValue("processPath"),
       flutter::EncodableValue(WideToUtf8(process_path))},
      {flutter::EncodableValue("processName"),
       flutter::EncodableValue(WideToUtf8(process_name))},
      {flutter::EncodableValue("idleSeconds"),
       flutter::EncodableValue(GetIdleSeconds())},
  };
}

}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateWindowsUsageChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == kGetActiveWindowInfo) {
          result->Success(GetActiveWindowInfo());
          return;
        }

        result->NotImplemented();
      });

  return channel;
}
