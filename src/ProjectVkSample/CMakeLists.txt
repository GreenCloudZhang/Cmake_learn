project(MyVkSample)
#查找当前目录下所有源文件
#并将名称保存在DIR_LIB_SRCS目录
#aux_source_directory(. DIR_LIB_SRCS)

#指定头文件目录
#include_directories(${PROJECT_SOURCE_DIR}/include)

#指定可执行文件的输出目录，输出到bin目录下
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_SOURCE_DIR}/bin)

find_package(Vulkan REQUIRED)
#生成动态库
#add_library(shared_demo SHARED lib.cpp)
#设置输出动态库名shared->libshared.so
#set_target_properties(shared_demo PROPERTIES OUTPUT_NAME "shared")

#生成静态库
#add_library(static_demo STATIC lib.cpp)
#设置输出静态库名static->libstatic.a
#set_target_properties(static_demo PROPERTIES OUTPUT_NAME "static")

#指定库输出文件路径
#set(LIBRARY_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/lib)

#在指定目录查找库，保存在变量LIBPaths
#find_library(LIB_PATHS shared ${PROJECT_SOURCE_DIR}/lib)

file(GLOB STBIMAGE_FILES_H ${CMAKE_SOURCE_DIR}/extern/stb_image/*.h)
file(GLOB STBIMAGE_FILES_C ${CMAKE_SOURCE_DIR}/extern/stb_image/*.c)

add_library(STBIMAGE ${STBIMAGE_FILES_H} ${STBIMAGE_FILES_C})
#target_include_directories(lua PUBLIC ${LUA_FILES_H})

#生成指定target
add_executable(helloVK 
helloVK.cpp
)

target_link_libraries(helloVK PUBLIC 
Vulkan::Vulkan 
${CMAKE_SOURCE_DIR}/extern/glfw/lib-vc2022/glfw3.lib
STBIMAGE)
target_include_directories(helloVK PUBLIC
${CMAKE_SOURCE_DIR}/extern/glm
${CMAKE_SOURCE_DIR}/extern/glfw/include
${CMAKE_SOURCE_DIR}/extern/stb_image)
