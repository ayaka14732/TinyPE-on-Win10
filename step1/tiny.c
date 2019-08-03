#include <Windows.h>

int main() {
    MessageBoxW( NULL /* hWnd */,
                 L"ABCDEFG" /* lpText, 16 bytes */,
                 L"💯 TinyPE on Windows 10" /* lpCaption, 48 bytes */,
                 MB_ICONASTERISK | MB_TOPMOST | MB_SERVICE_NOTIFICATION /* uType */ );
    return 0;
}
