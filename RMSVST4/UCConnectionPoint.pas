unit UCConnectionPoint;

interface

uses Vst3Base,UVSTBase,UCPlugView,UVST3Processor,SysUtils;

type CConnectionPoint = class(TAggregatedObject,IConnectionPoint)
private
  IVST3:IVSTBase;
  Fother: IConnectionPoint;
    procedure sendMessage(msg:TBytes);
    procedure SetOther(other: IConnectionPoint);
public
      // Connects this instance with an another connection point.
      function Connect(other: IConnectionPoint): TResult; stdcall;
      // Disconnects a given connection point from this.
      function Disconnect(other: IConnectionPoint): TResult; stdcall;
      // Called when a message has been send from the connection point to this.
      function Notify(msg: IMessage): TResult; stdcall;
  constructor Create(const Controller: IVSTBase);
end;

implementation
{ CConnectionPoint }

uses UCodeSiteLogger,UVST3Utils,Math;

constructor CConnectionPoint.Create(const Controller: IVSTBase);
begin
  inherited Create(controller);
  WriteLog('CConnectionPoint.Create');
  IVST3:=Controller;
  Fother:=NIL;
end;


procedure CConnectionPoint.SetOther(other: IConnectionPoint);
begin
  Fother:=other;
  if other<>NIL then IVST3.SetMessageSendHandler(sendMessage)
                else IVST3.SetMessageSendHandler(NIL);
end;

procedure CConnectionPoint.sendMessage(msg:TBytes);
VAR
    i,l:integer;
    imsg: IMessage;
    obj:pointer;
    buf:array[0..127] of byte;
begin
   if Fother=NIL then exit;
   if IVST3.host.CreateInstance(TUID(UID_IMessage),TUID(UID_IMessage),obj) <> kResultOk then exit;
   imsg:=IMessage(obj);
   imsg.SetMessageID('ByteMessage');
   l:=min(128,length(msg));
   for i:=0 to l-1 do
     buf[i]:=msg[i];
   IAttributeList(imsg.GetAttributes).setBinary('Bytes',@buf,l);
   Fother.Notify(imsg);
   imsg._Release;
end;

function CConnectionPoint.Connect(other: IConnectionPoint): TResult;
begin
  WriteLog('CConnectionPoint.Connect');
  SetOther(other);
  result:=kResultTrue;
end;

function CConnectionPoint.Disconnect(other: IConnectionPoint): TResult;
begin
  WriteLog('CConnectionPoint.DisConnect');
  SetOther(NIL);
  result:=kResultTrue;
end;

{$POINTERMATH ON}
function CConnectionPoint.Notify(msg: IMessage): TResult;
VAR id:string;
    i:integer;
    p:pointer;
    pb:^byte;
    l:longword;
    rcv:TBytes;
begin
  WriteLog('CConnectionPoint.Notify');
  id:=msg.GetMessageID;
  if id = 'ByteMessage' then
  begin
    IAttributeList(msg.GetAttributes).getBinary('Bytes',p,l);
    SetLength(rcv,l);
    pb:=p;
    for i:=0 to l-1 do rcv[i]:=pb[i];
    IVST3.ReceiveMessage(rcv);
  end;
  result:=kResultTrue;
end;

end.

