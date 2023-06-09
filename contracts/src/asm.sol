// SPDX-License-Identifier: Apache-2.0
pragma ton-solidity =0.69.0;
pragma ignoreIntOverflow;
pragma AbiHeader notime;

abstract contract Asm {
// begin Asm

function __CONT_BEGIN() internal inline pure { tvm.log("_PUSHCONT {"); }
function __CONT_TO_C3() internal inline pure { tvm.log("_}\nPOP c3"); }

function __C3_JMPX() internal inline pure { tvm.log("_PUSH c3\nJMPX"); }

function __CONT_LNRUN() internal inline pure { tvm.log("_}\nEXECUTE"); }
function __CONT_RETRN() internal inline pure { tvm.log("_RET"); }

function __throw_zero() internal pure { tvm.log("_THROW 0"); }
function __throw_not_supported() internal pure { tvm.log("_THROW404"); }
function __throw_internal_error() internal pure { tvm.log("_THROW 500"); }

function __C3_GOTO() internal inline pure { 
    tvm.log("_PUSH c3"); 
    tvm.log("_POP c0"); 
    tvm.log("_RET"); 
}

function __save_c1_to_glob_8() internal pure {
    tvm.log("_PUSH c1");
    tvm.log("_SETGLOB 8");
}

function __glob8_to_c0() internal pure {
    tvm.log("_GETGLOB 8");
    tvm.log("_POP c0");
}

function __simple_transfer_body() internal pure returns (TvmCell) {
    tvm.log("0:2:PUSHREF {");
    tvm.log("_.blob ZERO32");
    tvm.log("_}");
}

function __uint_to_bool(uint x) internal pure returns(bool) { 
    abi.encode(uint256(x));
    tvm.log("2:6:"); 
}

function __coins_to_uint(varUint16 x) internal pure returns(uint) { 
    abi.encode(uint256(x));
    tvm.log("2:6:"); 
}

function __uint_to_coins(uint x) internal pure returns(varUint16) { 
    abi.encode(uint256(x));
    tvm.log("2:6:"); 
}

function __dict_u7s_to_cell(mapping (uint7 => TvmSlice) x) 
        internal pure returns(TvmCell) { x; tvm.log("0:3:"); }


function __optional_uint7_cell_get_first(optional(uint7, TvmCell) x) 
                                    internal pure returns (uint7) {
    x;
    tvm.log("0:2:FIRST");
}

function __is_k_exists_7(uint7 k, TvmCell dict) internal pure returns(bool) {
    k; dict;
    tvm.log("0:2:PUSHINT 7");
    tvm.log("_DICTUGET");
    tvm.log("_NULLSWAPIFNOT");
    tvm.log("_NIP");
}

function __force_address(address addr) pure internal { 
    abi.encode(address(addr));
    tvm.log("0:4:SLICE x801_"); 
    tvm.log("0:0:SWAP");
    tvm.log("0:0:SDPFX");
    tvm.log("_THROWIFNOT 40");
}

function __preload_uint8(TvmSlice cs) pure internal returns (uint8) { 
    abi.encode(TvmSlice(cs));
    tvm.log("0:6:PLDU 8");
}

function __empty_slice() pure internal returns (TvmSlice) {
    tvm.log("0:1:SLICE x");
}

function __unsafe_drop() pure internal {
    tvm.log("0:0:DROP");
}

function __my_address() pure internal returns (TvmSlice) {
    tvm.log("0:1:MYADDR");
}

function __end_parse(TvmSlice cs) pure internal { 
    abi.encode(TvmSlice(cs));
    tvm.log("0:4:ENDS"); 
}

function __randomize_lt() pure internal {
    tvm.log("_LTIME"); 
    tvm.log("_ADDRAND"); 
}

function __cell_is_null(TvmCell c) pure internal returns (bool) {
    abi.encode(TvmCell(c));
    tvm.log("0:6:ISNULL"); 
}

function __addrbase_from_init(TvmCell c) pure internal returns (TvmSlice) {
    abi.encode(TvmCell(c));
    tvm.log("0:6:HASHCU"); 
    tvm.log("0:0:SLICE x801_"); 
    tvm.log("0:0:NEWC"); 
    tvm.log("0:0:STSLICE"); 
    tvm.log("0:0:STU 256"); 
    tvm.log("0:0:ENDC"); 
    tvm.log("0:0:CTOS"); 
}

function __set_fwd(uint x) internal pure { 
    abi.encode(x); tvm.log("0:4:SETGLOB 3"); 
}

function __get_fwd() internal pure returns (uint) { 
    tvm.log("0:1:GETGLOB 3"); 
}

// end Asm
}
