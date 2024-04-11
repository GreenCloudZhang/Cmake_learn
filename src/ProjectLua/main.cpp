#include <iostream>
//#include "lib.h"
//#pragma comment(lib, "lua.lib")
//extern "C"
//{
//#include "../extern/lua-5.4.6/include/lua.h"
//#include "../extern/lua-5.4.6/include/lualib.h"
//#include "../extern/lua-5.4.6/include/lauxlib.h"
#include "../../extern/lua-5.4.6/include/lua.hpp"
//}

///* thread status */
//#define LUA_OK		0
//#define LUA_YIELD	1
//#define LUA_ERRRUN	2
//#define LUA_ERRSYNTAX	3
//#define LUA_ERRMEM	4
//#define LUA_ERRERR	5

static int add_three(lua_State* L)
{
    int a = lua_tonumber(L, -1);
    int b = lua_tonumber(L, -2);
    int c = lua_tonumber(L, -3);
    int sum = a + b + c;
    lua_pushnumber(L, sum);
    return 1;
}

int main(void){
    std::cout<<"Test Lua\n";
    ////PrintLibMsg();
    char lua_filename[] = "D:\CodeRepo\CmakeLearn\Cmake_learn\src\test.lua";
    lua_State* L = luaL_newstate();
    int status = luaL_dofile(L, lua_filename);
    lua_getglobal(L, "number");
    printf("number:%f\n", lua_tonumber(L, -1));
    lua_register(L, "add3", add_three);

    lua_getglobal(L, "add3");
    lua_pushinteger(L, 10);
    lua_pushinteger(L, 20);
    lua_pushinteger(L, 30);
    lua_pcall(L, 3, 1, 0);

    int res = lua_tonumber(L, -1);
    std::cout << "res: " << res << "\n";

    return 0;
}