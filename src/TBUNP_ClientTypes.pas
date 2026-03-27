unit TBUNP_ClientTypes;

interface

uses
  TBUNP_CommonTypes;

type
  // 连接状态
  TOwnState = (ownsConnected, ownsDisconnected);
  
  // 客户端专用回调类型
  TPCDisconnectCb = procedure(aPipe: Cardinal) of object; stdcall;
  TPCErrorCb      = TGenericErrorCb;     // 复用通用类型
  TPCMessageCb    = TGenericMessageCb;   // 复用通用类型
  TPCSentCb       = TGenericSentCb;      // 复用通用类型

implementation

end.