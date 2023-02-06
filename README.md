# Running BakkesMod on Linux with Steam Proton

## Prerequisites
I had to install these packages along the process. I'm on Fedora 36 though, so package names may vary depending on what distro you're on:

- `protontricks`
- `mingw64-gcc-c++`
- `mingw64-winpthreads-static`

## Installing BakkesMod

Download BakkesMod from [the official website](https://bakkesmod.com). 

This installer is only compatible with Windows 10, and proton prefixes are Windows 7 by default. You can get the Windows 7 version of BakkesMod or just change your Windows version like I did:

1. Run `protontricks 252950 --gui`. Ignore any warnings about 64bit prefixes, everything's okay.
2. Select the default wineprefix
![w10step1](https://user-images.githubusercontent.com/8140592/181131149-3b130fe7-2d1a-4b78-82a8-dd2a55887734.png)
3. Change settings
![w10step2](https://user-images.githubusercontent.com/8140592/181131202-26cf8eee-1236-490c-b2bb-fa82f781b2bb.png)
4. Tick the win10 box
![w10step3](https://user-images.githubusercontent.com/8140592/181131232-eda2e419-e4b9-43d3-abff-443112d76697.png)

Now you can run the installer like this:

```
protontricks -c '/home/$USER/Downloads/BakkesModSetup.exe' 252950
```

This should run the installer in the same wine prefix where Rocket League is installed. 252950 is Rocket League's Steam APPID.

Now you might be tempted to just run BakkesMod with protontricks, but it won't work:

![vcredisterror](https://user-images.githubusercontent.com/8140592/181131265-14ddcc26-15df-4081-90c6-09c0d61fbc4a.png)

Installing `vcredistx64` doesn't fix anything, it still gives that error (trust me, I tried). It's the injector that doesn't play well with Proton for some reason, so we'll have to make our own.

## Making our own injector

First create a file named `inject.cpp` with this content:

```cpp
#include <windows.h>

#include <tlhelp32.h>

#include <iostream>
#include <string>

#define LOG_LINE(x, msg) std::cout << msg << std::endl;

DWORD GetProcessID64(std::wstring processName)
{
  PROCESSENTRY32 processInfo;
  processInfo.dwSize = sizeof(processInfo);

  HANDLE processesSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, NULL);
  if (processesSnapshot == INVALID_HANDLE_VALUE)
    return 0;

  Process32First(processesSnapshot, &processInfo);
  if (_wcsicmp(processName.c_str(), processInfo.szExeFile) == 0)
  {

    BOOL iswow64 = FALSE;
    // https://stackoverflow.com/questions/14184137/how-can-i-determine-whether-a-process-is-32-or-64-bit
    // If IsWow64Process() reports true, the process is 32-bit running on a
    // 64-bit OS So we want it to return false (32 bit on 32 bit os, or 64 bit on
    // 64 bit OS, since we build x64 the first condition will never satisfy since
    // they can't run this exe)

    auto hProcess =
        OpenProcess(PROCESS_ALL_ACCESS, FALSE, processInfo.th32ProcessID);
    if (hProcess == NULL)
    {
      LOG_LINE(INFO, "Error on OpenProcess to check bitness");
    }
    else
    {

      if (IsWow64Process(hProcess, &iswow64))
      {
        // LOG_LINE(INFO, "Rocket league process ID is " <<
        // processInfo.th32ProcessID << " | " << " has the WOW factor: " <<
        // iswow64);
        if (!iswow64)
        {
          CloseHandle(processesSnapshot);
          return processInfo.th32ProcessID;
        }
      }
      else
      {
        LOG_LINE(INFO, "IsWow64Process failed bruv " << GetLastError());
      }
      CloseHandle(hProcess);
    }
  }

  while (Process32Next(processesSnapshot, &processInfo))
  {
    if (_wcsicmp(processName.c_str(), processInfo.szExeFile) == 0)
    {
      BOOL iswow64 = FALSE;
      auto hProcess =
          OpenProcess(PROCESS_ALL_ACCESS, FALSE, processInfo.th32ProcessID);
      if (hProcess == NULL)
      {
        LOG_LINE(INFO, "Error on OpenProcess to check bitness");
      }
      else
      {

        if (IsWow64Process(hProcess, &iswow64))
        {
          // LOG_LINE(INFO, "Rocket league process ID is " <<
          // processInfo.th32ProcessID << " | " << " has the WOW factor: " <<
          // iswow64);
          if (!iswow64)
          {
            CloseHandle(processesSnapshot);
            return processInfo.th32ProcessID;
          }
        }
        else
        {
          LOG_LINE(INFO, "IsWow64Process failed bruv " << GetLastError());
        }
        CloseHandle(hProcess);
      }
    }
    // CloseHandle(processesSnapshot);
  }

  CloseHandle(processesSnapshot);
  return 0;
}

int wmain(int argc, wchar_t* argv[])
{
  DWORD processID;
  while (true)
  {
    processID = GetProcessID64(L"RocketLeague.exe");
    if (processID != 0)
      break;
    Sleep(100);
  }

  HANDLE h = OpenProcess(PROCESS_ALL_ACCESS, false, processID);
  if (h)
  {
    LPVOID LoadLibAddr = (LPVOID)GetProcAddress(
        GetModuleHandleW(L"kernel32.dll"), "LoadLibraryW");
    auto ws = L"C:\\users\\steamuser\\Application Data\\bakkesmod\\bakkesmod/dll\\bakkesmod.dll";
    auto wslen = (std::wcslen(ws) + 1) * sizeof(WCHAR);
    LPVOID dereercomp = VirtualAllocEx(
        h, NULL, wslen, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    WriteProcessMemory(h, dereercomp, ws, wslen, NULL);
    HANDLE asdc = CreateRemoteThread(
        h,
        NULL,
        NULL,
        (LPTHREAD_START_ROUTINE)LoadLibAddr,
        dereercomp,
        0,
        NULL);
    WaitForSingleObject(asdc, INFINITE);
    DWORD res = 0;
    GetExitCodeThread(asdc, &res);
    LOG_LINE(INFO, "GetExitCodeThread(): " << (int)res);
    LOG_LINE(INFO, "Last error: " << GetLastError());
    VirtualFreeEx(h, dereercomp, wslen, MEM_RELEASE);
    CloseHandle(asdc);
    CloseHandle(h);
    return res == 0;
  }
  return 1;
}
```

Once you have it, compile it with this command:

```
x86_64-w64-mingw32-g++ inject.cpp -municode -mconsole -lpsapi -std=c++17 -o inject.exe -static
```

It should spit out a file called `inject.exe`. You can test it by starting Rocket League, waiting for the game to load completely and running your shiny new injector:

```
protontricks -c 'wine ~/inject.exe' 252950
```

After a few seconds you should be able to hit F2 and see the BakkesMod GUI.

This injector should work in any Proton version, I'm using Proton 6.3-8.

## Running the injector when Rocket League starts

For this trick we're gonna make a shell script that runs Rocket League, waits for it to launch completely and then runs the injector.

Create a file called `bakkesinject.sh` with this content:

```bash
echo "" > ~/steam-252950.log

eval 'PROTON_LOG=1 "$@"' &

while ! grep "Initializing Engine Completed" ~/steam-252950.log > /dev/null; do
    sleep 1
done

protontricks -c 'wine ~/inject.exe' 252950
```

Make it executable with `chmod +x bakkesinject.sh` and add it to the launch parameters of Rocket League like this:

![launchparams](https://user-images.githubusercontent.com/8140592/181131575-78b90b81-d485-4f4b-9332-4598be0bdf9a.png)

## Updating BakkesMod

The injector doesn't take care of updating BakkesMod, so whenever a new version comes out, you'll have to run the good old GUI like this:

```
protontricks -c 'wine "/home/$USER/.steam/steam/steamapps/compatdata/252950/pfx/drive_c/Program Files/BakkesMod/BakkesMod.exe"' 252950
```

You can make this an alias or another bash script, like I did.

Once it finishes updating you can close it. IMPORTANT: Do not attempt to launch Rocket League while the BakkesMod GUI is running, it won't work. For some reason the game doesn't like when you launch it while something else is running in its prefix (you can run anything after the game has launched though).

## References

Everything is taken from [this GitHub issue](https://github.com/bakkesmodorg/BakkesMod2-Plugins/issues/2). The custom injector code comes from [this GitHub gist](https://gist.github.com/blastrock/6958033f03a0bdffa52c6dfa2ce0e60a), which is also referenced in the GitHub issue. The launch script is heavily inspired on [this comment from the GitHub issue](https://github.com/bakkesmodorg/BakkesMod2-Plugins/issues/2#issuecomment-897120768), I just simplified some parts of it.
