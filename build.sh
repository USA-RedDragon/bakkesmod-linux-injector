#!/bin/bash

x86_64-w64-mingw32-g++ inject.cpp -municode -mconsole -lpsapi -std=c++17 -o inject.exe -static
