// Lightweight ATL compatibility header.
// Replaces CA2W / CW2A with standard Windows API calls,
// eliminating the need for the ATL library.

#pragma once
#include <string>
#include <windows.h>

class CA2W {
public:
    CA2W(const char* psz) {
        if (!psz) return;
        int len = MultiByteToWideChar(CP_ACP, 0, psz, -1, nullptr, 0);
        if (len > 0) {
            buf_.resize(len);
            MultiByteToWideChar(CP_ACP, 0, psz, -1, &buf_[0], len);
        }
    }
    const wchar_t* m_psz() const { return buf_.data(); }
    operator const wchar_t*() const { return buf_.data(); }
    const wchar_t* m_psz;
    std::wstring buf_;
};

class CW2A {
public:
    CW2A(const wchar_t* psz) {
        if (!psz) return;
        int len = WideCharToMultiByte(CP_ACP, 0, psz, -1, nullptr, 0, nullptr, nullptr);
        if (len > 0) {
            buf_.resize(len);
            WideCharToMultiByte(CP_ACP, 0, psz, -1, &buf_[0], len, nullptr, nullptr);
        }
    }
    operator const char*() const { return buf_.data(); }
    std::string buf_;
};
