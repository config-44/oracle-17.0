import { Address, BOC, Cell } from '@eversdk/ton'
import axios from 'axios'

interface SendResult<T> {
    data: T;
    status: number;
}

export interface RPC<T> {
    id: string;
    jsonrpc: string;
    result: T;
}

export interface GetAccount {
    id: string;
    acc_type: number;
    boc: string;
    data: string;
    code_hash: string;
    balance: string;
    acc_type_name: string;
    data_hash: string;
    code: string;
    workchain_id: string;
}

export class EverspaceCenter {
    private _endpoint: string

    private _key: string

    constructor (endpoint: string, key: string) {
        this._endpoint = endpoint
        this._key = key
    }

    private static wrapJrpc (method: string, params: any) {
        return { id: '1', jsonrpc: '2.0', method, params }
    }

    private makeHeaders () {
        return { 'Content-Type': 'application/json', 'X-API-KEY': this._key }
    }

    private async send<T> (method: string, req: any): Promise<SendResult<T>> {
        const { data, status } = await axios.post<T>(
            this._endpoint,
            EverspaceCenter.wrapJrpc(method, req),
            { headers: this.makeHeaders() }
        )

        return { data, status }
    }

    public async getAccount (address: Address): Promise<RPC<GetAccount>> {
        const res = await this.send<RPC<GetAccount>>(
            'getAccount',
            { address: address.toString('raw') }
        )

        if (res.status !== 200) throw new Error(`got not 200 ok: ${res}`)

        return res.data
    }

    public async sendAndWaitTransaction (msg: Cell): Promise<void> {
        const res = await this.send(
            'sendAndWaitTransaction',
            { boc: BOC.toBase64Standard(msg) }
        )

        if (res.status !== 200) throw new Error(`got not 200 ok: ${res}`)
    }
}
