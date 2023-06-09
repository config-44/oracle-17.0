import { BOC, Builder, Block, Address, nacl, Utils } from '@eversdk/ton'
import * as fs from 'fs'
import { EverspaceCenter } from './utils'

const file2b = (file: string): Buffer => fs.readFileSync(file)

const PKFILE = './build/Example.pk'
const ADDRFILE = './build/Example.addr.txt'

const SEND_REQUEST = 1614189761

async function main () {
    const rpcURL = process.env.RPC || ''

    if (rpcURL === '') {
        console.log('set RPC env to https://everspace.center/ jrpc provider')
        process.exit(1)
    }

    if (process.argv.length !== 3) {
        console.log('unexpected number of arguments')
        console.log('usage: yarn request <url>')
        process.exit(1)
    }

    const url: string = process.argv[2]
    const provider = new EverspaceCenter(rpcURL, 'todo')

    console.log(`Loading keypair from:\t${PKFILE}`)
    const keypair = nacl.sign.keyPair.fromSeed(file2b(PKFILE))
    console.log(`Restored pubkey:\t${Utils.Helpers.bytesToHex(keypair.publicKey)}`)

    console.log(`\nLoading address from:\t${ADDRFILE}`)
    const address = new Address(file2b(ADDRFILE).toString('utf-8'))
    console.log(`Loaded address: \t${address.toString('raw')}`)

    const account = await provider.getAccount(address)
    const accountData = BOC.fromStandard(account.result.data).parse()
    accountData.skipBits(256 + 1)
    accountData.loadAddress()
    const seqno = accountData.loadUint(16)

    console.log(`\nremote account seqno:\t${seqno}`)

    const validUntil = ~~(Date.now() / 1000) + 60
    const queryCell = new Builder().storeString(url).cell()

    const bodycs = new Builder()
        .storeUint(SEND_REQUEST, 32)  // op
        .storeUint(seqno, 16)         // seqno
        .storeUint(validUntil, 64)    // valid_until
        .storeRef(queryCell)          // url
        .cell()
        .parse()

    const bodyWithAddress = new Builder()
        .storeAddress(address)
        .storeSlice(bodycs)

    const sign = Utils.Helpers.signCell({
        cell: bodyWithAddress.cell(),
        privateKey: keypair.secretKey
    })

    const extmsgBody = new Builder()
        .storeBit(1)      // Maybe
        .storeBytes(sign) // signature
        .storeSlice(bodycs)

    const extmsg = new Block.Message({
        info: new Block.CommonMsgInfo({
            tag: 'ext_in_msg_info',
            dest: address
        }),
        body: extmsgBody.cell()
    })

    console.log('sending an external message ...')
    await provider.sendAndWaitTransaction(extmsg.cell)
    console.log('done')
}

main()
