// SPDX-License-Identifier: Apache-2.0
pragma ton-solidity =0.69.0;
pragma ignoreIntOverflow;
pragma AbiHeader notime;

import "./asm.sol";

varUint16 constant MAX_GAS    = 1 ton;
varUint16 constant EYE_TARGET = 1 ton;

uint7 constant ORACLE_QUERY_SET = 4;

library OP {
    uint32 constant ACCEPT_REWARD = 0x00000000;
    uint32 constant REQUEST_QUERY = 0x00000001;
    uint32 constant APPLY_FOR_NEW = 0x00000002;
    uint32 constant REQUEST_SLASH = 0x00000003;
    uint32 constant MASTER_EXEC_P = 0x00000004;
}

library PROPOSAL {
    uint8 constant ORACLE = 0x01;
    uint8 constant PSLASH = 0x02;
}

contract Eye is Asm {
// begin Eye

uint256   private _master_key;

uint32    private _proposal_timeout;
varUint16 private _total_stake;
varUint16 private _min_stake;
varUint16 private _max_stake;
varUint16 private _min_voting_reward;

varUint16 private _total_rewards;

uint8                         private _proposals_count;
mapping (uint64  => TvmCell)  private _proposal_list;
mapping (uint256 => TvmSlice) private _active_proposers;
mapping (uint7   => TvmCell)  private _current_list;

TvmCell private _req_code;

function __load_data() private { /* .macro load_data */ } 
function __save_data() private { /* .macro save_data */ }

function recv_internal(varUint16 balance, varUint16 value, 
                       TvmCell msg_, TvmSlice body) private {
    
    __unsafe_drop();

    require(!body.empty() && body.bits() >= 32, 101 /* invalid msg body */);

    TvmSlice msgcs = msg_.toSlice();

    __uint_to_bool(msgcs.decode(uint4) & 1); // bounced
    address sender = msgcs.decode(address);

    __force_address(sender);
    
    // TODO: use fwd fee in checks 
    // msgcs.decode(address, varUint16, uint1, varUint16);
    // __set_fwd(math.muldiv(__coins_to_uint(msgcs.decode(varUint16)), 3, 2));
    
    __load_data();

    uint32 op       = body.decode(uint32);
    uint64 query_id = body.decode(uint64);
    
    __CONT_BEGIN(); __save_data(); __CONT_TO_C3();

    if (op == OP.ACCEPT_REWARD) {
        _total_rewards += __uint_to_coins(math.max(0, 
                          __coins_to_uint(value - 0.1 ton)));
        
        __C3_GOTO();
    }

    if (_proposals_count > 0) { 
        uint64 ts = block.timestamp;

        for ((uint64 k, TvmCell v) : _proposal_list) {
            if (ts <= uint32(k >> 32)) break;

            (, uint256 pubkey) = v.toSlice().decode(uint8, uint256);
            delete _active_proposers[pubkey];
            delete _proposal_list[k];
        }
    }

    require(value >= MAX_GAS, 102);

    if (op == OP.REQUEST_QUERY) {
        __randomize_lt();

        (uint7 max_key, ) = _current_list.max().get();
        require(max_key >= ORACLE_QUERY_SET + 2, 333);

        mapping (uint7 => TvmCell) query_set;
        mapping (uint7 => TvmCell) _current_list_t = _current_list;

        uint7 counter = 0;
        while (counter < ORACLE_QUERY_SET) {
            (uint7 max_key_t, TvmCell cur_max_v) = _current_list_t.max().get();
            uint7 new_rnd = rnd.next(max_key_t + 1);

            query_set[counter] = _current_list_t.fetch(new_rnd).get();

            _current_list_t[new_rnd] = cur_max_v;
            delete _current_list_t[max_key_t];

            counter += 1;
        }

        {
            require(counter == ORACLE_QUERY_SET, 366); // assert
            require(query_set.fetch(0).hasValue(), 367); // assert

            (uint7 assert_key, ) = query_set.max().get();
            require(assert_key == (ORACLE_QUERY_SET - 1), 368); // assert
        }
        
        TvmCell query_cell = body.loadRef();

        TvmBuilder req_data;
        req_data.storeSigned(0, 1);               // _inited
        req_data.store(TvmSlice(__my_address())); // _eye_address
        req_data.store(sender);                   // _client_addr
        req_data.store(tvm.hash(query_cell));     // _equery_hash

        // _oracle_list, _builder_id, _result, _votes, _votes_count, _finished
        req_data.storeUnsigned(0, 1 + 7 + 1 + 1 + 7 + 1); 
        req_data.storeUnsigned(ORACLE_QUERY_SET, 7); // _oracle_count
        req_data.storeUnsigned(tx.timestamp, 64);    // _salt

        TvmBuilder req_state_init_b;
        req_state_init_b.storeUnsigned(6, 5); // 0b00110
        req_state_init_b.storeRef(_req_code); // code
        req_state_init_b.storeRef(req_data);  // data
        TvmCell req_state_init = req_state_init_b.toCell();

        TvmBuilder req_body_b;
        req_body_b.storeUnsigned(0xf0e109c0, 32); // op: INIT
        req_body_b.storeUnsigned(query_id, 64);   // query_id
        req_body_b.store(sender);                 // client_addr
        req_body_b.store(query_set);              // query_set
        req_body_b.storeRef(query_cell);          // query_cell

        TvmBuilder msg_int_b;
        msg_int_b.storeUnsigned(0x10, 6); // bounce false
        msg_int_b.store(__addrbase_from_init(req_state_init));
        msg_int_b.storeUnsigned(0, 4 + 1 + 4 + 4 + 64 + 32);
        msg_int_b.storeUnsigned(2, 2); // 0b10
        msg_int_b.store(req_state_init_b);
        msg_int_b.storeUnsigned(0, 1); // 0b0
        msg_int_b.store(req_body_b);

        tvm.rawReserve(math.max(__coins_to_uint(balance) - value, 
                        __coins_to_uint(EYE_TARGET)), 0);
    
        tvm.sendrawmsg(msg_int_b.toCell(), 128);

        __C3_GOTO();
    }

    if (op == OP.APPLY_FOR_NEW) {
        require(value >= _min_stake + _min_voting_reward + MAX_GAS, 102);
        require(_proposals_count <= 255, 103);

        TvmSlice sign = body.loadSlice(512);

        TvmCell  proposal = body.loadRef();
        TvmSlice ps       = proposal.toSlice();

        uint8     ps_tag           = ps.decode(uint8);
        uint256   ps_pubkey        = ps.decode(uint256);
                                     ps.decode(uint256);  // ps_adnl_addr
        varUint16 ps_stake         = ps.decode(varUint16);
        varUint16 ps_voting_reward = ps.decode(varUint16);

        __end_parse(ps);

        require(ps_tag == 0x01 && 
                ps_stake >= _min_stake && 
                ps_stake <= _max_stake && 
                ps_voting_reward >= _min_voting_reward, 104);

        optional(TvmSlice) is_proposer = _active_proposers.fetch(ps_pubkey);
        require(!is_proposer.hasValue(), 105);

        _active_proposers[ps_pubkey] = __empty_slice();

        uint256 proposal_hash = tvm.hash(proposal);
        tvm.checkSign(proposal_hash, sign, ps_pubkey);

        uint64 pidx = ((block.timestamp + _proposal_timeout) << 32) +
                      uint32(proposal_hash & 0xFFFFFFFF);

        _proposal_list[pidx] = proposal;
        _proposals_count++;
        
        tvm.rawReserve(balance - value + ps_stake + ps_voting_reward, 0);
        sender.transfer(0, false, 128);

        __C3_GOTO();
    }

    if (op == OP.REQUEST_SLASH) {
        require(_proposals_count <= 255, 103);

        TvmSlice sign = body.loadSlice(512);

        TvmCell  proposal = body.loadRef();
        TvmSlice ps       = proposal.toSlice();

        uint8     ps_tag         = ps.decode(uint8);
        uint256   ps_from_pubkey = ps.decode(uint7);
        uint7     ps_from_id     = ps.decode(uint7);
                                   ps.decode(uint7);     // ps_toward_id
                                   ps.decode(varUint16); // ps_size

        __end_parse(ps);

        require(ps_tag == 0x02, 104);

        TvmSlice from_cs = _current_list.fetch(ps_from_id).get().toSlice();
        uint256  from_pubkey = from_cs.decode(uint256);

        require(from_pubkey == ps_from_pubkey, 228);
        uint256 proposal_hash = tvm.hash(proposal);
        tvm.checkSign(proposal_hash, sign, from_pubkey);

        optional(TvmSlice) is_proposer = _active_proposers.fetch(from_pubkey);
        require(!is_proposer.hasValue(), 105);

        _active_proposers[from_pubkey] = __empty_slice();

        uint64 pidx = ((block.timestamp + _proposal_timeout) << 32) +
                      uint32(proposal_hash & 0xFFFFFFFF);

        _proposal_list[pidx] = proposal;
        _proposals_count++;
        
        tvm.rawReserve(math.max(__coins_to_uint(balance) - value, 
                        __coins_to_uint(EYE_TARGET)), 0);

        sender.transfer(0, false, 128);

       __C3_GOTO();
    }

    if (op == OP.MASTER_EXEC_P) {
        TvmSlice sign = body.loadSlice(512);
        
        uint256 tail_hash = tvm.hash(body);
        tvm.checkSign(tail_hash, sign, _master_key);

        uint64 pidx = body.decode(uint64);
        TvmSlice ps = _proposal_list.fetch(pidx).get().toSlice();

        uint8 ps_tag = ps.decode(uint8);

        if (ps_tag == PROPOSAL.ORACLE) {
            delete _proposal_list[pidx];
            _proposals_count--;

            // pubkey + adnl_addr
            uint256 pubkey = ps.decode(uint256);
            delete _active_proposers[pubkey];

            uint256 adnl_addr = ps.decode(uint256);
            varUint16 stake   = ps.decode(varUint16);

            TvmBuilder oracle_b;
            oracle_b.store(pubkey);
            oracle_b.store(adnl_addr);
            oracle_b.storeTons(stake);

            optional(uint7, TvmCell) kvcl = _current_list.max();

            uint7 next = 0;
            if (kvcl.hasValue()) {
                uint7 key = __optional_uint7_cell_get_first(kvcl);
                next = key + 1;
            }

            _current_list[next] = oracle_b.toCell();
            sender.transfer(0, false, 64);

        } else if (ps_tag == PROPOSAL.PSLASH) {

            delete _proposal_list[pidx];
            _proposals_count--;

            uint256   from_pubkey = ps.decode(uint256);
                                    ps.decode(uint7); // from_id
            uint7     toward_id   = ps.decode(uint7);
            varUint16 size        = ps.decode(varUint16);

            TvmSlice oracle = _current_list.fetch(toward_id).get().toSlice();

            delete _active_proposers[from_pubkey];
            delete _current_list[toward_id];

            (, , varUint16 prsnd_stake) = (
                oracle.decode(uint256), 
                oracle.decode(uint256), 
                oracle.decode(varUint16)
            );

            // TODO: send (prsnd_stake - size) back to oracle
            // with initialization of a new locker wallet smc
            address(0).transfer(prsnd_stake - size, false, 1);

            // distribute slashed amount in rewards
            _total_rewards += size; 
        }

        __C3_GOTO();
    }

    __throw_not_supported();
}

// end Eye
}
