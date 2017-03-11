# Laravel Application Profiler

Based on Tideways(fork of XHProf) and XHGui.

## Install

Cd into your laravel project, and download this project. We assume you are going to checkout to `profiler` branch.

```bash
~ $ cd your-laravel 
~/your-laravel(master) $ git checkout -b profiler
~/your-laravel(profiler) $ wget https://github.com/appkr/laravel-xhprofiler/archive/latest.tar.gz
~/your-laravel(profiler) $ tar zxvf latest.tar.gz
~/your-laravel(profiler) $ cp -r laravel-xhprofiler-latest/* ./ && rm -rf laravel-xhprofiler-latest
```

## Build

```bash
~/your-laravel(profiler) $ docker build --tag profiler .
```

## Run

```bash
~/your-laravel(profiler) $ docker run -d \
    --name profiler \
    -p 9001:9001 \
    -p 9002:9002 \
    -p 28017:28017 \
    -p 8000:80 \
    -v `pwd`/xhgui_data:/var/lib/mongodb/ \
    profiler:latest
```

## Action

Send some traffic to http://localhost:8000 and then checkout the profiling result at http://localhost:9002
