import chronos

proc readLineAsync*(file: File): Future[string] =
  let fd = file.getFileHandle()
  let asyncFd = wrapAsyncSocket(fd.cint)
  let res = newFuture[string]()
  proc handleFile(arg: pointer) {.gcsafe, raises: [].} = 
    var inp: string
    try:
      inp = file.readLine()
    except CatchableError as e:
      res.fail(e)
    try:
      asyncFd.removeReader()
    except CatchableError as e:
      res.fail(e)
    try:
      asyncFd.unregister()
    except CatchableError as e:
      res.fail(e)
    res.complete(inp)
  asyncFd.addReader(handleFile)
  return res
