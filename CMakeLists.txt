#Cmake最新版本号要求
cmake_minimum_required(VERSION 3.4)

#指定项目名称
project(CmakeDemo)

#指定版本信息
set(CMAKE_SYSTEM_VERSION 1)

#指定编译选项
set(CMAKE_BUILD_TYPE Debug)

#指定编译目录
set(PROJECT_BINARY_DIR ${PROJECT_SOURCE_DIR}/build)

#find_package(pybind11 REQUIRED)

#添加Cmake子目录，进入src cmakelists继续构建
add_subdirectory(src/ProjectLua MyLUA)
#pybind11_add_module(example example.cpp)