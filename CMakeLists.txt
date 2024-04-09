#Cmake最新版本号要求
cmake_minimum_required(VERSION 2.8)

#指定项目名称
project(CmakeDemo)

#指定版本信息
set(CMAKE_SYSTEM_VERSION 1)

#指定编译选项
set(CMAKE_BUILD_TYPE Debug)

#指定编译目录
set(PROJECT_BINARY_DIR ${PROJECT_SOURCE_DIR}/build)

#添加Cmake子目录，进入src cmakelists继续构建
add_subdirectory(${PROJECT_SOURCE_DIR}/src)