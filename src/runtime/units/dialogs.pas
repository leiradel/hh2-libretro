unit Dialogs;

interface

type
    TMsgDlgType = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);
    TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore, mbAll, mbNoToAll, mbYesToAll, mbHelp, mbClose);
    TMsgDlgButtons = set of TMsgDlgBtn;

function MessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; HelpCtx: Longint): Integer;

implementation

function MessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons; HelpCtx: Longint): Integer;
begin
    MessageDlg := 0;
end;

end.