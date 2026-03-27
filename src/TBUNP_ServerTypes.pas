unit TBUNP_ServerTypes;

interface

uses
  TBUNP_CommonTypes;

type
  // 服务器专用回调类型
  TPSConnectCb    = procedure(aPipe: Cardinal) of object; stdcall;
  TPSDisconnectCb = procedure(aPipe: Cardinal) of object; stdcall;
  TPSErrorCb      = TGenericErrorCb;     // 复用通用类型
  TPSMessageCb    = TGenericMessageCb;   // 复用通用类型
  TPSSentCb       = TGenericSentCb;      // 复用通用类型

implementation

end.