import libp2p/protobuf/minprotobuf
import std/times

type 
  Chat* = object
    user*: string
    timestamp*: string
    message*: string

proc new*(_: typedesc[Chat], user: string, message: string, timestamp: DateTime = now()): Chat =
  Chat(
    user: user,
    message: message,
    timestamp: timestamp.format("yyyy-MM-dd hh:mm:ss")
  )

proc encode*(c: Chat): ProtoBuffer =
  result = initProtoBuffer()
  result.write(1, c.user)
  result.write(2, c.timestamp)
  result.write(3, c.message)
  result.finish()

proc decode*(_: type Chat, buf: seq[byte]): Result[Chat, ProtoError] =
  var res: Chat
  let pb = initProtoBuffer(buf)
  discard ?pb.getField(1, res.user)
  discard ?pb.getField(2, res.timestamp)
  discard ?pb.getField(3, res.message)
  ok(res)