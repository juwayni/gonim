# runtime/stdlib/net.nim
import ../builtin
import std/net as nimnet

type
  Addr* = interface
    proc Network*(): string
    proc String*(): string

  Conn* = interface
    proc Read*(b: GoSlice[byte]): (int, GoError)
    proc Write*(b: GoSlice[byte]): (int, GoError)
    proc Close*(): GoError
    proc LocalAddr*(): Addr
    proc RemoteAddr*(): Addr

  TCPConn* = object
    socket: nimnet.Socket

proc Dial*(network, address: string): (Conn, GoError) =
  let sock = nimnet.dial(address, nimnet.IPProtocol.IPPROTO_TCP)
  # Wrap in TCPConn and return as interface
  discard
