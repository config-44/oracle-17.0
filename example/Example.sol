// SPDX-License-Identifier: Apache-2.0
pragma ton-solidity =0.69.0;
pragma ignoreIntOverflow;
pragma AbiHeader notime;

int8   constant WORKCHAIN     = 0;
uint16 constant UINT16_MAX    = 2 ** 16 - 1;
uint32 constant REQUEST_QUERY = 0x00000001;

uint16 constant _req_data_depth = 0;

contract Example {


    // begin storage
    address _eye_address;
    uint16  _seqno;
    string  _last_result;

    uint256 _req_code_hash;
    uint16  _req_code_depth;
    // end storage


    // send new http query from this contract
    function send_request(
        uint16 seqno, uint64 valid_until, string url
    ) external externalMsg 
    {
        require(msg.pubkey() == tvm.pubkey(), 100);
        require(valid_until >= block.timestamp, 101);
        require(seqno == _seqno, 102);

        tvm.accept();

        TvmBuilder body;
        body.store(uint32(REQUEST_QUERY)); // op
        body.store(uint64(tx.timestamp));  // query_id
        body.store(string(url));           // query_cell

        _eye_address.transfer(2 ton, true, 3, body.toCell());

        _seqno = (_seqno + 1) % UINT16_MAX;
    }


    // more gas efficient than in stdlib_sol.tvm
    function state_init_hash_with_zero_data_depth(
        uint256 data_h, uint256 code_h, uint16 code_d
    ) private pure returns (uint256) 
    {
        TvmBuilder b;
        b.store(uint24(131380));
        b.store(uint16(code_d));
        b.store(uint16(0));
        b.store(uint256(code_h));
        b.store(uint256(data_h));

        return sha256(b.toCell().toSlice());
    }


    // query response processing
    function process_result(
        uint256 equery_hash, uint4 query_set, uint64 salt, string res
    ) 
        external
        internalMsg
        functionID(0xfd131c15)
    {
        TvmBuilder req_data_b;
        req_data_b.store(int1(0));
        req_data_b.store(address(_eye_address));
        req_data_b.store(address(this));
        req_data_b.store(uint256(equery_hash));
        req_data_b.storeUnsigned(0, 1 + 7 + 1 + 1 + 7 + 1); 
        req_data_b.storeUnsigned(query_set, 7); 
        req_data_b.storeUnsigned(salt, 64); 

        uint256 req_init_hash = state_init_hash_with_zero_data_depth(
            tvm.hash(req_data_b.toCell()),
            _req_code_hash, 
            _req_code_depth
        );

        address expected_req = address.makeAddrStd(WORKCHAIN, req_init_hash);
        require(expected_req == msg.sender, 401); // unauthorized request
    
        _last_result = res;
    }


    // get last http query result
    function get_last_result() view external externalMsg returns (string) {
        return _last_result;
    }

}