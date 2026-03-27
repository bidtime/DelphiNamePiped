unit TBUNP_CommonTypes;

interface

type
  HPIPE = THandle;

  // 管道上下文类型
  TPipeContext = (pcListener, pcWorker);
  
  // 通用错误回调类型
  TGenericErrorCb = procedure(aPipe: Cardinal; aPipeContext: ShortInt; 
                              aErrorCode: Integer) of object; stdcall;
                              
  // 通用消息回调类型
  TGenericMessageCb = procedure(aPipe: Cardinal; aMsg: PWideChar) of object; stdcall;
  
  // 通用发送完成回调类型
  TGenericSentCb = procedure(aPipe: Cardinal; aSize: Cardinal) of object; stdcall;

implementation

end.