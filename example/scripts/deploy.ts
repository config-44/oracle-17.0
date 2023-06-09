import { BOC, Builder, Cell, Block, Address, nacl } from '@eversdk/ton'
import * as fs from 'fs'
import { EverspaceCenter } from './utils'

// eslint-disable-next-line no-promise-executor-return
const sleep = (ms: number) => new Promise(r => setTimeout(r, ms))

const file2b = (file: string): Buffer => fs.readFileSync(file)
const b2boc = (bytes: Buffer): Cell => BOC.fromStandard(bytes)
const emptyRef = () => new Builder().cell()

const CODE = './build/Example.boc'
const PKFILE = './build/Example.pk'
const INFOBOC = './build/req-code-info.boc'
const ADDRFILE = './build/Example.addr.txt'

async function main () {
    const rpcURL = process.env.RPC || ''
    const infocs = b2boc(file2b(INFOBOC)).parse()
    const exampleCode = b2boc(file2b(CODE)).parse().loadRef()

    if (process.argv.length !== 3) {
        console.log('unexpected number of arguments')
        console.log('usage: yarn deploy <eye-address>')
        process.exit(1)
    }

    if (rpcURL === '') {
        console.log('set RPC env to https://everspace.center/ jrpc provider')
        process.exit(1)
    }

    let eyeAddress = Address.NONE

    try {
        eyeAddress = new Address(process.argv[2])
    } catch (error) {
        console.log(`invalid argument: ${error}`)
        process.exit(1)
    }

    const provider = new EverspaceCenter(rpcURL, 'todo')

    const keypair = nacl.sign.keyPair()
    const publicKey = keypair.publicKey
    const secretKey = keypair.secretKey.slice(0, 32)

    fs.writeFileSync(PKFILE, secretKey)
    console.log(`Private key saved to:\t'${PKFILE}'`)

    const code = new Builder()
        .storeUint(0xFF00, 16) // SETCP0
        .storeUint(0xF800, 16) // ACCEPT
        .storeRef(exampleCode) // => ref
        .storeUint(0x88, 8)    // PUSHREF
        .storeUint(0xFB04, 16) // SETCODE
        .cell()

    const data = new Builder()
        .storeBytes(publicKey)    // _pubkey
        .storeInt(-1, 1)          // _constructorFlag
        .storeAddress(eyeAddress) // _eye_address
        .storeUint(0, 16)         // _seqno
        .storeRef(emptyRef())     // _last_result
        .storeRef(
            // _req_code_hash + _req_code_depth
            new Builder().storeSlice(infocs).cell()
        )
        .cell()

    const stateInit = new Block.StateInit({ code, data })
    const address = new Address(`0:${stateInit.cell.hash()}`)

    fs.writeFileSync(ADDRFILE, address.toString('raw'))
    console.log(`Address saved to:\t'${ADDRFILE}'`)

    console.log(`Example.sol address:\t${address.toString('raw')}`)
    console.log('\nplease send ~5 tokens to this address (awaiting ...)')

    while (true) {
        try {
            const res = await provider.getAccount(address)
            const balance = BigInt(res.result.balance)
            if (balance < 4_500_000_000n) continue
            break
        } catch (error) {
            sleep(1000)
            continue
        }
    }

    const extmsg = new Block.Message({
        info: new Block.CommonMsgInfo({
            tag: 'ext_in_msg_info',
            dest: address
        }),
        init: stateInit
    })

    console.log('sending an external message ...')
    await provider.sendAndWaitTransaction(extmsg.cell)
    console.log('done')
}

main()
