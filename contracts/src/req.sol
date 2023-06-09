// SPDX-License-Identifier: Apache-2.0
pragma ton-solidity =0.69.0;
pragma ignoreIntOverflow;
pragma AbiHeader notime;

import "./asm.sol";

library OP {
    uint32 constant INIT           = 0xf0e109c0;
    uint32 constant SUBMIT_RESULT  = 0xde1c6a17;
    uint32 constant CONFIRM_RESULT = 0x9a6ff4ff;

    uint32 constant PROCESS_RESULT = 0xfd131c15;
}

uint7 constant ORACLE_QUERY_SET = 4;

contract Req is Asm {
// begin Req

bool                        private _inited;       // + 1   bit
address                     private _eye_address;  // + 267 bit
address                     private _client_addr;  // + 267 bit
uint256                     private _equery_hash;  // + 267 bit

mapping (uint7 => TvmCell)  private _oracle_list;  // + 1  bit 1 ref
uint7                       private _builder_id;   // + 7  bit
TvmCell                     private _result;       // + 1  bit 1 ref(maybe null)
mapping (uint7 => TvmSlice) private _votes;        // + 1  bit 1 ref
uint7                       private _votes_count;  // + 7  bit
bool                        private _finished;     // + 1  bit
uint7                       private _oracle_count; // + 7  bit
uint64                      private _salt;         // + 64 bit

function __load_data() private { /* .macro load_data */ } 
function __save_data() private { /* .macro save_data */ }

function __unpack_data() private pure { 
    tvm.log("_PUSH c4");
    tvm.log("_CTOS");

    tvm.log("_LDI 1");      // _inited
    tvm.log("_LDMSGADDR");  // _eye_address
    tvm.log("_LDMSGADDR");  // _client_addr
    tvm.log("_LDU 256");    // _equery_hash
    tvm.log("_LDDICT");     // _oracle_list
    tvm.log("_LDU 7");      // _builder_id
    tvm.log("_LDDICT");     // _result
    tvm.log("_LDDICT");     // _votes
    tvm.log("_LDU 7");      // _votes_count
    tvm.log("_LDI 1");      // _finished
    tvm.log("_LDU 7");      // _oracle_count
    tvm.log("_PLDU 64");    // _salt

    tvm.log("_SETGLOB 21"); // _salt
    tvm.log("_SETGLOB 20"); // _oracle_count
    tvm.log("_SETGLOB 19"); // _finished
    tvm.log("_SETGLOB 18"); // _votes_count
    tvm.log("_SETGLOB 17"); // _votes
    tvm.log("_SETGLOB 16"); // _result
    tvm.log("_SETGLOB 15"); // _builder_id
    tvm.log("_SETGLOB 14"); // _oracle_list
    tvm.log("_SETGLOB 13"); // _equery_hash
    tvm.log("_SETGLOB 12"); // _client_addr
    tvm.log("_SETGLOB 11"); // _eye_address
    tvm.log("_SETGLOB 10"); // _inited
} 

function __pack_data() private pure { 
    tvm.log("_GETGLOB 21"); // _salt
    tvm.log("_GETGLOB 20"); // _oracle_count
    tvm.log("_GETGLOB 19"); // _finished
    tvm.log("_GETGLOB 18"); // _votes_count
    tvm.log("_GETGLOB 17"); // _votes
    tvm.log("_GETGLOB 16"); // _result
    tvm.log("_GETGLOB 15"); // _builder_id
    tvm.log("_GETGLOB 14"); // _oracle_list
    tvm.log("_GETGLOB 13"); // _equery_hash
    tvm.log("_GETGLOB 12"); // _client_addr
    tvm.log("_GETGLOB 11"); // _eye_address
    tvm.log("_GETGLOB 10"); // _inited

    tvm.log("_NEWC");
    tvm.log("_STI 1");      // _inited
    tvm.log("_STSLICE");    // _eye_address
    tvm.log("_STSLICE");    // _client_addr
    tvm.log("_STU 256");    // _equery_hash
    tvm.log("_STDICT");     // _oracle_list
    tvm.log("_STU 7");      // _builder_id
    tvm.log("_STDICT");     // _result
    tvm.log("_STDICT");     // _votes
    tvm.log("_STU 7");      // _votes_count
    tvm.log("_STI 1");      // _finished
    tvm.log("_STU 7");      // _oracle_count
    tvm.log("_STU 64");     // _salt
    tvm.log("_ENDC");    
   
    tvm.log("_POP c4");
}

function recv_internal(TvmCell msg_, TvmSlice body) private {

    __unsafe_drop();
    
    require(!body.empty() && body.bits() >= 32, 101 /* invalid msg body */);

    TvmSlice msgcs = msg_.toSlice();
    if (__uint_to_bool(msgcs.decode(uint4) & 1)) { __throw_zero(); }

    address sender = msgcs.decode(address);
    __force_address(sender);

    __unpack_data();

    (uint32 op, ) = body.decode(uint32, uint64); // op, query_id

    if (op == OP.INIT) {
        require(!_inited, 111);
        require(_eye_address == sender, 228);

        _oracle_list = body.decode(mapping (uint7 => TvmCell));

        TvmCell requet_cell = body.loadRef();
        require(tvm.hash(requet_cell) == _equery_hash, 155);

        __randomize_lt();
        (uint7 max_key, ) = _oracle_list.max().get();
        _builder_id = rnd.next(max_key + 1);

        _inited = true;

        __pack_data();
        __throw_zero();
    }

    __throw_not_supported();
}

function recv_external(TvmSlice body) private {
    __unsafe_drop();

    uint32 op = body.decode(uint32);
    
    __unpack_data();
    require(!_finished, 325);

    __CONT_BEGIN(); __pack_data(); __CONT_TO_C3();

    if (op == OP.SUBMIT_RESULT) {
        require(__cell_is_null(_result), 444);

        TvmSlice sign = body.loadSlice(512);
        TvmSlice tail = body;

        uint7 oracle_id = body.decode(uint7);
        require(oracle_id == _builder_id, 129);

        TvmSlice oracle = _oracle_list.fetch(oracle_id).get().toSlice();
        tvm.checkSign(tvm.hash(tail), sign, oracle.decode(uint256));

        tvm.accept();

        _result = body.loadRef();
        _votes[oracle_id] = __empty_slice();
        _votes_count++;

        __C3_GOTO();
    }

    if (op == OP.CONFIRM_RESULT) {
        require(!__cell_is_null(_result), 277);

        TvmSlice sign = body.loadSlice(512);
        TvmSlice tail = body;

        uint7 oracle_id = body.decode(uint7);
        require(oracle_id != _builder_id, 229);

        require(!__is_k_exists_7(oracle_id, __dict_u7s_to_cell(_votes)), 336);

        TvmSlice oracle = _oracle_list.fetch(oracle_id).get().toSlice();
        tvm.checkSign(tvm.hash(tail), sign, oracle.decode(uint256));

        tvm.accept();

        _votes[oracle_id] = __empty_slice();
        _votes_count++;

        if (_votes_count * 100 >= math.muldiv(_oracle_count, 5100, 100)) {
            TvmBuilder result_body;
            result_body.store(uint32(OP.PROCESS_RESULT));
            result_body.store(uint256(_equery_hash));
            result_body.store(uint4(ORACLE_QUERY_SET));
            result_body.store(uint64(_salt));
            result_body.storeRef(_result);

            _eye_address.transfer(0.5 ton, false, 2, __simple_transfer_body());
            _client_addr.transfer(0, false, 128, result_body.toCell());

            _finished = true;
        }

        __C3_GOTO();
    }

    __throw_not_supported();
}

// end Req
}
