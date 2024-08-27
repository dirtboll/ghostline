import libp2p/protobuf/minprotobuf, libp2p


# TODO: Unify these two
type 
  InitUser* = object
    username*: string
    bootstrapPeerId*: PeerId
    bootstrapPeerAddr*: MultiAddress
  User* = object
    username*: string

proc new*(_: typedesc[User], username: string): User =
  User(
    username: username
  )

proc encode*(c: User): ProtoBuffer =
  result = initProtoBuffer()
  result.write(1, c.username)
  result.finish()

proc decode*(_: typedesc[User], buf: seq[byte]): Result[User, ProtoError] =
  var res: User
  let pb = initProtoBuffer(buf)
  discard ?pb.getField(1, res.username)
  ok(res)

