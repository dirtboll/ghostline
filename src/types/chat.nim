import libp2p/protobuf/minprotobuf
import std/times

import ./user

type 
  Chat* = object
    user*: User
    timestamp*: string
    message*: string

proc new*(_: typedesc[Chat], username: string, message: string, timestamp: DateTime = now()): Chat =
  Chat(
    user: User.new(username),
    message: message,
    timestamp: timestamp.format("yyyy-MM-dd hh:mm:ss")
  )

proc new*(_: typedesc[Chat], user: User, message: string, timestamp: DateTime = now()): Chat =
  Chat(
    user: user,
    message: message,
    timestamp: timestamp.format("yyyy-MM-dd hh:mm:ss")
  )

proc encode*(c: Chat): ProtoBuffer =
  result = initProtoBuffer()
  let userPb = c.user.encode()
  result.write(1, userPb)
  result.write(2, c.timestamp)
  result.write(3, c.message)
  result.finish()

proc decode*(_: typedesc[Chat], buf: seq[byte]): Result[Chat, ProtoError] =
  var res: Chat
  let pb = initProtoBuffer(buf)
  var userPb: ProtoBuffer
  discard ?pb.getField(1, userPb)
  res.user = ?User.decode(userPb.buffer)
  discard ?pb.getField(2, res.timestamp)
  discard ?pb.getField(3, res.message)
  ok(res)