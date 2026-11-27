unit DeskMain;

{$mode objfpc}{$H+}

interface

uses
  InfoBar, Toast, Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls, ActnList, Menus,
  Dialogs, IniPropStorage, LMessages, fpjson, InkMemo, InkListBox, InkLabel, CrossDragDropData, CrossDragDropHelpers, DeskThread, DeskNet,
  FileAssMan, FileAssInstance, FAInstanceCore, FATypes, DeskOversight, DeskMembers, DeskChannels, DeskAdminLogic, DeskRoomList, DeskActions,
  DeskContent, DeskStatus, DeskPictures, DeskIcons;

type
  // The form stays editable with the installed list-box component.
  TInkListBox = class(TDeskRoomList);

  TMainForm = class(TForm)
    NoticeBar: TInfoBar;
    NoticeToast: TToast;
    RoomList: TInkListBox;
    Splitter1: TSplitter;
    ThreadPane: TThreadFrame;
    Splitter3: TSplitter;
    RoomPanel: TPanel;
    MemberList: InkListBox.TInkListBox;
    Splitter2: TSplitter;
    RoomHeader: TInkLabel;
    HeaderRule: TShape;
    Messages: TInkMemo;
    TypingLabel: TLabel;
    ComposerPanel: TPanel;
    ButtonBox: TPanel;
    Composer: TMemo;
    AnswerPanel: TPanel;
    AnswerLabel: TLabel;
    CancelAnswerButton: TButton;
    SendButton: TButton;
    CodeButton: TButton;
    ServersMenu, ConnectMenu, OpenConnectItem, SaveConnectItem, ConnectSeparator, AssocItem, UnassocItem: TMenuItem;
    FileAss: TFileAssMan;
    Instance: TFileAssInstance;
    ActionList1: TActionList;
    ActSend: TAction;
    ActSignOut: TAction;
    ActQuit: TAction;
    ActReload: TAction;
    ActAbout: TAction;
    ActPeople: TAction;
    ActFind, ActFindHere, ActPins, ActSettings, ActLock: TAction;
    RoomMenu, FindItem, FindHereItem, PinsItem, SettingsItem, PinItem, RoomSeparator, LockItem: TMenuItem;
    ViewMenu: TMenuItem;
    PeopleItem: TMenuItem;
    Icons: TImageList;
    MainMenu1: TMainMenu;
    FileMenu: TMenuItem;
    ReloadItem: TMenuItem;
    FileSeparator: TMenuItem;
    SignOutItem: TMenuItem;
    QuitItem: TMenuItem;
    HelpMenu: TMenuItem;
    AdminMenu, MembersItem, ChannelsItem, PrivateItem: TMenuItem;
    AboutItem: TMenuItem;
    PingTimer: TTimer;
    PropStorage: TIniPropStorage;
    AttachButton: TButton;
    FileExpiryBox: TComboBox;
    MessageMenu: TPopupMenu;
    RowMenu: TPopupMenu;
    RowLeaveItem, RowDeleteChannelItem, RowDeleteDmItem: TMenuItem;
    RowSilenceItem, RowMentionsItem, RowNotifyAllItem: TMenuItem;
    ReactItem: TMenuItem;
    ThreadItem, AnswerItem, CopyItem, CopyLinkItem, MenuSeparator, EditItem, DeleteItem: TMenuItem;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    Tray: TTrayIcon;
    procedure NoticeAnswer(Sender: TObject; const Key: string; Answer: TModalResult);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure RoomListClick(Sender: TObject);
    procedure RoomListMenu(Sender: TObject; Index: integer; const MenuPosition: TPoint);
    procedure RowActionClick(Sender: TObject);
    procedure MessagesLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
    procedure MessagesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure MessagesResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
    procedure MessagesScroll(Sender: TObject);
    procedure ComposerKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure ComposerKeyPress(Sender: TObject; var Key: char);
    procedure ActSendExecute(Sender: TObject);
    procedure ActSignOutExecute(Sender: TObject);
    procedure ActQuitExecute(Sender: TObject);
    procedure ActReloadExecute(Sender: TObject);
    procedure ActAboutExecute(Sender: TObject);
    procedure PingTimerTimer(Sender: TObject);
    procedure ActPeopleExecute(Sender: TObject);
    procedure ComposerChange(Sender: TObject);
    procedure AttachButtonClick(Sender: TObject);
    procedure MessageMenuPopup(Sender: TObject);
    procedure ReactClick(Sender: TObject);
    procedure AnswerClick(Sender: TObject);
    procedure CancelAnswerClick(Sender: TObject);
    procedure ThreadItemClick(Sender: TObject);
    procedure CopyItemClick(Sender: TObject);
    procedure CopyLinkItemClick(Sender: TObject);
    procedure EditItemClick(Sender: TObject);
    procedure DeleteItemClick(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure CodeButtonClick(Sender: TObject);
    procedure HeaderLinkClick(Sender: TObject; const LinkName: string);
    procedure FormResize(Sender: TObject);
    procedure ParametersGiven(Sender: TObject; Parameters: TStrings; const WorkingDirectory: utf8string; Initial: boolean);
    procedure OpenConnectClick(Sender: TObject);
    procedure SaveConnectClick(Sender: TObject);
    procedure AssocClick(Sender: TObject);
    procedure UnassocClick(Sender: TObject);
    procedure ActFindExecute(Sender: TObject);
    procedure ActPinsExecute(Sender: TObject);
    procedure ActSettingsExecute(Sender: TObject);
    procedure PinItemClick(Sender: TObject);
    procedure ActFindHereExecute(Sender: TObject);
    procedure ActLockExecute(Sender: TObject);
    procedure MemberListClick(Sender: TObject);
    procedure PrivateClick(Sender: TObject);
    procedure MembersClick(Sender: TObject);
    procedure ChannelsClick(Sender: TObject);
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  private
    MyName: string;          // who signed in
    MyKeyName, DmKeyName, OpenKeyName: string;
    MenuEntry: integer;      // the message the menu was opened on, its place in Shown
    MenuId: integer;         // and its id, which survives older messages coming in above
    MenuRoom: string;
    MenuEpoch: integer;
    Filling: boolean;        // entries are being added: a scroll is not a request for older ones
    Drafts: TStringList;     // what was typed and not sent, by room (line ends as #1)
    DraftBeforeEdit: string; // the draft put aside while a message is edited
    EditingId: integer;      // the message the composer edits, 0 for a new one
    EditPayload: TJSONObject;
    EditSealed: boolean;     // the message being edited came locked
    DmReply: TJSONObject;
    ReplySerial, SentReplySerial: integer;
    LastTyping: QWord;       // when the server was last told about typing
    TypingSeen: QWord;       // when someone else was last seen typing
    TypingTimer: TTimer;     // takes the typing note away when they stop
    DropTarget: TCrossDragDropTarget; // files dropped on the composer attach
    AttachRow: TInkLabel;    // the files attached so far, each with a remove link
    ComposerBase: integer;   // the composer panel's height without that row
    LastReadId: integer;     // the newest message read before this visit to the room
    DividerId: integer;      // the first message after it by someone else, under a New messages line
    Suggest: TListBox;       // names, rooms or commands for the word being typed
    SuggestTimer: TTimer;
    RetryAttempt, RetryStatus: integer;
    OutageSince, RetryDue: QWord;
    RetryBusy, ProbePending, ReauthPending, SignInEnded: boolean;
    ChatOff: boolean;
    PollingWorks: boolean;
    RetrySendRoom, ConnectionText: string;
    RetrySendEpoch: integer;
    LiveRetry: TTimer;       // starts the live connection again soon after it drops
    SuggestNames: TStringList;
    SuggestQuery: string;
    SuggestGen: integer;
    SuggestStart: integer;   // where that word begins in the composer (1-based)
    Commands: TStringList;   // name=usage from /api/commands, fetched once
    MarkId: integer;         // a message just jumped to, lit for a moment
    MarkTimer: TTimer;       // takes that light away
    PendingTarget: string;   // where the last notification came from, for a click on the tray
    NoticePending: boolean;
    NoticeChannel: string;
    NoticeSerial, SyncNoticeSerial: integer;
    NoticeBefore: TJSONArray;
    TrayMenu: TPopupMenu;
    TrayCount: integer;
    DeleteDmItem: TMenuItem;
    Attached: TJSONArray;    // files uploaded for the next message
    AutoAway: integer;       // minutes without input before showing as away, 0 never
    LastInput: QWord;        // when the member last pressed a key or the mouse
    Idle: boolean;           // shown as away because of that
    DmLocked: boolean;       // the private conversation on show is locked
    DmKey: TBytes;           // the key it is sealed with, once opened
    Slugs: TStringList;      // the room behind each line of RoomList
    Room: string;            // the room on show
    Shown: TJSONArray;       // its messages, oldest first, top level only
    Previews: TPreviewState;
    Since: int64;            // the rev to ask /api/sync from
    MoreBefore: boolean;     // the server has older ones than Shown[0]
    Fetching: boolean;        // older ones are on the way
    Pictures: TPictureCache;   // address, and the bytes as a TBytesStream; nil while on the way
    Downloads, DownloadPending: TStringList;
    IconClock: QWord;
    IconSerial: integer;
    IconUse: byte;
    Uploading, UploadGen: integer;
    KeyWrap: TBytes;
    KeyGeneration: integer;
    KeyAnswer, KeyPassword: string;
    KeyPromptGeneration: integer;
    procedure KeySaltDone(Job: TApiJob);
    procedure MyKeyDone(Job: TApiJob);
    procedure UploadDone(Job: TApiJob);
    procedure DownloadDone(Job: TApiJob);
    procedure SaveDownload(const FileToken, FileName, IV: string; const Key: TBytes);
    procedure NewRoomDone(Job: TApiJob);
    procedure SignOutDone(Job: TApiJob);
    procedure PictureDropped(const Path: string);
  private
    IconIndex: TStringList;  // a picture's address or 'letter:' + name, and its place in Icons + 1; 0 while on the way
    RoomsSeen: TJSONArray;   // the last room list, private conversations and people from the server
    DmsSeen: TJSONArray;
    HereSeen: TJSONArray;
    Staff: TJSONArray;       // a private room's members, or who runs a public one
    MemberNames: TStringList; // the name behind each line of MemberList, '' for a heading
    Card: TJSONObject;       // the room on show as /api/room describes it: topic, private, following, can; nil in a conversation
    MyCan: TStringList;      // what this member may do on the site (/api/me's can): open rooms, and so on; nil until read
    MyReactions: TJSONObject; // the reactions the site offers (/api/me's reactions: shown and more); nil until read
    CanTalk: boolean;        // the composer sends here; otherwise it shows why not
    WhyNot: string;          // the server's reason when it does not
    NewRoomItem, TopicItem, InviteItem, KickItem, LeaveItem: TMenuItem;
    NarrowMode: boolean;     // one column: the room, or the list or a thread in its place
    ListInFront: boolean;    // in one column, the room list is what shows
    WideListWidth: integer;  // the list's width in two columns, kept while in one
    HeadPic: integer;        // the header as last shown, drawn again when the columns change
    HeadTitle, HeadNote: string;
    TextScale: integer;      // the messages' text size in percent, this computer's setting
    DmReadDue: boolean;      // private messages were fetched while the window was away; told as read on return
    DmCheckDue: boolean;     // a ring may mean this conversation was emptied
    DmReload: TJSONArray;
    DmReloadFirst, DmReloadLast: integer;
    RoomGen: integer;        // counts room openings; an answer tagged with an older count is for a room since left
    SyncBusy, SyncAgain: boolean; // one sync out at a time, and whether another was asked for meanwhile
    IdleBusy: boolean;       // an away or back notice is out
    DmNewsBusy: boolean;     // the conversation's news is being read
    SeenId: integer;         // the newest of my messages the other has read, which says so; 0 for none
    Sending: boolean;        // a message is on its way
    SentText: string;        // what was sent; the composer is cleared only while it still holds that
    SentRoom: string;
    SentAttach: integer;     // AttachGen when it was sent
    AttachGen: integer;      // counts changes to Attached
    Opening: string;         // the room or @conversation being opened
    OpeningBusy: boolean;    // and whether its messages are still on their way
    OpenLocked: boolean;     // what /api/key said about it, until its messages are in
    OpenPub: string;
    FallBack: boolean;       // the room being opened is the saved one; gone, the first will do
    AfterOpen: string;       // words to send once the conversation is open (/msg name words)
    AfterOpenFor: string;    // the conversation they are for ('@name'): they go nowhere else
    ThreadAfter: integer;    // a thread to open once its room is
    JumpId, JumpPages: integer; // a message to land on, and the pages read for it so far
    FillPages: integer;      // pages read to fill a short room
    Accounts: TStringList;   // server=token for every server signed in to, to come back without a password
    Started: boolean;        // Start has run once; a change of server starts again
    SettingsRead: boolean;   // the ini has been read; nothing is written before that
    ThemePaper, ThemeInk: TColor; // the system's window colors as last seen; a change recolors
    Oversight: TOversightForm;
    MemberAdmin: TMembersForm;
    ChannelAdmin: TChannelsForm;
    ClosedWords: string;     // why the channel on show closed, until it is shown
    RowTarget: string;
    RowEpoch: integer;
    RowActionBusy: boolean;
    procedure ChannelsChanged(Sender: TObject);
    function SidebarRoom(const Slug: string): TJSONObject;
    procedure ActOnRow(Target: string; RowAction: TRowAction);
    procedure RowActionDone(Job: TApiJob);
    procedure RefreshRooms;
    procedure RoomsDone(Job: TApiJob);
    procedure RemoveDmMessage(Id: integer);
    procedure DmDeleteDone(Job: TApiJob);
    procedure PrivateDeleted(const Kind, Slug, NameA, NameB: string);
    procedure ClearCurrent;
    procedure ChannelClosed(const Words: string);
    procedure ShowClosed(Data: PtrInt);
    procedure LiveRetryTick(Sender: TObject);
    procedure ChatProbeDone(Job: TApiJob);
    function IconFor(const Url, Who: string; Letter: boolean): integer;
    procedure ClearIconUse(Use: byte);
    procedure IconArrived(const Path: string; Bytes: TBytes; FetchTag: integer);
    procedure ShowHeader(Pic: integer; const Title, Note: string);
    function DmAvatar(const Who: string): string;
    procedure ShowRooms;
    procedure ShowPeople;
    procedure ThreadClosed(Sender: TObject);
    procedure ThreadLink(const Link: string);
    procedure ThreadPicture(const URL: string; Destination: TStream; var Handled: boolean);
    procedure Fetched(const Path: string; Bytes: TBytes; FetchTag: integer);
    procedure FetchedPreview(const Path: string; Bytes: TBytes; FetchTag: integer);
    function KnownStatus(const Who: string): TMemberStatus;
    procedure FetchedSealed(const Path: string; Bytes: TBytes; FetchTag: integer);
    function SealedMeta(const Token: string): TJSONObject;
    function SealedMessageId(const FileToken: string): integer;
    procedure Start(Data: PtrInt);
    function SignIn(BlankServer: boolean = False): boolean;
    procedure SaveAccount;
    procedure OpenRoom(const Wanted: string);
    procedure LoadOlder;
    procedure Sync;
    procedure Render;
    procedure ShowNew(First: integer);
    function EntryHtml(I: integer): string;
    function EntryColor(I: integer): TColor;
    procedure PutEntry(I: integer);
    procedure Ring(const Kind, RingRoom, Who: string; Deleted, Edited: integer; Gone: boolean);
    procedure LiveGone;
    function LastId: integer;
    function InDm: boolean;
    procedure LoadDmNews;
    procedure ShowSeen;
    function Looking: boolean;
    function DmAsk(const Who: string; Ask: TDmAsk; Id: integer): string;
    procedure DmTellRead;
    procedure TellShown;
    procedure WindowStateChanged(Sender: TObject);
    procedure SendDm(const Words: string);
    function MenuMessage: TJSONObject;
    procedure OpenThreadOn(Id: integer);
    procedure StartEdit(I: integer);
    procedure StopEdit;
    procedure SendDmEdit(const Words: string);
    procedure DmEditDone(Job: TApiJob);
    procedure Notify(const Title, Words: string);
    procedure NotifyRooms(List: TJSONArray; Serial: integer);
    procedure UserInput(Sender: TObject; var Msg: TLMessage);
    procedure ShowRoomMenu;
    function RoomItem(At: integer; const Title: string; Handler: TNotifyEvent): TMenuItem;
    function RoomCan(const Perm: string): boolean;
    function SiteCan(const Perm: string): boolean;
    procedure RunCommand(const Line: string);
    procedure NewRoomClick(Sender: TObject);
    procedure TopicClick(Sender: TObject);
    procedure InviteClick(Sender: TObject);
    procedure KickClick(Sender: TObject);
    procedure LeaveClick(Sender: TObject);
    procedure ApplyLayout;
    procedure ShowList(InFront: boolean);
    procedure SavingProps(Sender: TObject);
    procedure ApplyScale;
    procedure Retheme;
    procedure ReadStaff;
    procedure SyncDone(Job: TApiJob);
    procedure ApplySync(Answer: TJSONObject; NoticeAtRequest: integer);
    procedure StaffDone(Job: TApiJob);
    procedure CardDone(Job: TApiJob);
    procedure RoomGoneDone(Job: TApiJob);
    procedure IdleDone(Job: TApiJob);
    procedure PostDone(Job: TApiJob);
    procedure EditDone(Job: TApiJob);
    procedure DmSentDone(Job: TApiJob);
    procedure PostedDone(Job: TApiJob);
    procedure CommandDone(Job: TApiJob);
    procedure TopicDone(Job: TApiJob);
    procedure DmLockDone(Job: TApiJob);
    procedure DmNewsDone(Job: TApiJob);
    procedure DmCheckDone(Job: TApiJob);
    procedure ReactToMessage(Id: integer; const Reaction: string);
    procedure DmReactDone(Job: TApiJob);
    procedure RefreshDm(Id: integer);
    procedure DmRefreshDone(Job: TApiJob);
    procedure ShowAnswer;
    procedure ClearAnswer;
    procedure PostThenSync(const Path: string; const Fields: array of string);
    procedure MeDone(Job: TApiJob);
    procedure FirstRoomDone(Job: TApiJob);
    procedure RoomDone(Job: TApiJob);
    procedure DmKeyDone(Job: TApiJob);
    procedure DmDone(Job: TApiJob);
    procedure OlderDone(Job: TApiJob);
    procedure LockDone(Job: TApiJob);
    procedure RoomFailed(const Words: string; Handled: boolean = False);
    procedure FillUp;
    procedure AfterOpened;
    procedure DropAfterOpen;
    procedure JumpStep;
    procedure Disconnect;
    procedure SwitchServer(const Url, Slug: string);
    procedure OpenConnectionFile(const Path: string);
    procedure WriteConnectionFile(const Path: string);
    procedure BuildServersMenu;
    procedure ServerPick(Sender: TObject);
    procedure AddServerClick(Sender: TObject);
    procedure ApiFailed(const Words: string);
    procedure ApiResult(Job: TApiJob);
    procedure ApiSignInEnded;
    procedure ReauthDone(Job: TApiJob);
    procedure ConnectionLost(Status: integer);
    procedure ShowConnection;
    procedure RetryConnection;
    procedure RetryDone(Job: TApiJob);
    procedure ShowError(E: Exception; const Key: string);
    procedure ShowJobError(Job: TApiJob; const Key: string);
    procedure SendFailed(Job: TApiJob);
    procedure DmNews;
    procedure StartConversation(const Command: string);
    procedure SaidTyping(const Who: string);
    procedure TypingTick(Sender: TObject);
    procedure FocusComposer;
    procedure AttachFile(const FileName: string);
    procedure StoreDraft;
    procedure TakeDraft;
    procedure LiveReady;
    procedure FormActivated(Sender: TObject);
    procedure ReadRoomCard;
    procedure ComposerDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
    procedure DropError(Sender: TObject; const Message: string);
    procedure GoToRoomClick(Sender: TObject);
    procedure ShowUnread(Count: integer);
    procedure ShowAttached;
    procedure ClearAttached;
    procedure AttachRowLink(Sender: TObject; const LinkName: string);
    procedure ReportClick(Sender: TObject);
    procedure UpdateSuggest;
    procedure SuggestTick(Sender: TObject);
    procedure SuggestDone(Job: TApiJob);
    procedure CommandsDone(Job: TApiJob);
    procedure SentAccepted;
    procedure AcceptSuggest;
    procedure HideSuggest;
    procedure SuggestClick(Sender: TObject);
    procedure FirstUnreadClick(Sender: TObject);
    procedure ScrollToEntry(I: integer);
    procedure JumpToMessage(const Slug: string; Id: integer);
    procedure FollowLink(var Picked: string; const Link: string);
    procedure MarkTick(Sender: TObject);
    procedure TrayBadge(Count: integer);
    procedure DeleteDmClick(Sender: TObject);
    function HaveMyKey(Job: TApiJob): boolean;
    function Readable(Item: TJSONObject): TJSONObject;
    procedure SaveSealed(const FileToken: string);
  end;

var
  MainForm: TMainForm;

implementation

uses
  IniFiles, LCLIntf, LazUTF8, LazFileUtils, LCLType, Clipbrd, StrUtils, Math, InterfaceBase, LazVersion, IntfGraphics, FPImage, GraphType, InkMarkdown,
  DeskKeys, DeskFind, DeskSettings, DeskRoom,
  DeskReport, DeskAbout, DeskLive, DeskView, DeskSignIn, DeskProfile, DeskConfig, fphttpclient;

  {$R *.lfm}

type
  TSealedDownload = class
  public
    FileToken, FileName, IV: string;
    Key: TBytes;
    MessageId: integer;
    destructor Destroy; override;
  end;

destructor TSealedDownload.Destroy;
begin
  WipeBytes(Key);
  inherited Destroy;
end;


const
  { rev counts microseconds; asking from a little before the last one
    catches what was written while the answer was made. }
  RevSlack = 3000000;

procedure TMainForm.FormCreate(Sender: TObject);
var
  Go, Rep, Sep: TMenuItem;
  I: integer;
begin
  // A second Exedra hands its files to the first and ends (FileAss):
  // nothing of the window is made for it.
  if Instance.Role = firSecondary then
    Exit;
  Randomize;
  PrepareConfig;
  PropStorage.IniFileName := ConfigFile;
  PropStorage.OnSavingProperties := @SavingProps;
  ApiOnError := @ApiFailed;
  ApiOnResult := @ApiResult;
  ApiOnSignInEnded := @ApiSignInEnded;
  with TIniFile.Create(ConfigFile) do
  try
    Server := ReadString('account', 'server', '');
    Token := ReadString('account', 'token', '');
    Room := ReadString('account', 'room', '');
    TextScale := ReadInteger('view', 'scale', 100);
    if (TextScale < 50) or (TextScale > 300) then
      TextScale := 100;
    Accounts := TStringList.Create;
    ReadSectionValues('accounts', Accounts);
  finally
    Free;
  end;
  SettingsRead := True;
  BuildServersMenu;
  Slugs := TStringList.Create;
  RoomList.RowKeys := Slugs;
  RoomList.OnRowMenu := @RoomListMenu;
  Shown := TJSONArray.Create;
  DmReload := TJSONArray.Create;
  Previews := TPreviewState.Create;
  Pictures := TPictureCache.Create;
  Pictures.OnDrop := @PictureDropped;
  Downloads := TStringList.Create;
  DownloadPending := TStringList.Create;
  Downloads.OwnsObjects := True;

  IconIndex := TStringList.Create;
  IconIndex.OwnsObjects := True;

  RoomsSeen := TJSONArray.Create;
  DmsSeen := TJSONArray.Create;
  HereSeen := TJSONArray.Create;
  Staff := TJSONArray.Create;
  Attached := TJSONArray.Create;
  MemberNames := TStringList.Create;
  AttachProfileMenu(MemberList, MemberNames, @MyName, @OpenRoom);
  Drafts := TStringList.Create;
  Commands := TStringList.Create;
  SuggestNames := TStringList.Create;
  // shown once it has its picture: Qt complains about a tray icon without one
  Tray.Icon.Assign(Application.Icon);
  Tray.Visible := True;
  TrayCount := -1;
  // The designer's sample header is not for the screen.
  RoomHeader.Caption := '';
  LastInput := GetTickCount64;
  Application.AddOnUserInputHandler(@UserInput);
  // The selected row is colored; a dotted frame on top of it is clutter.
  InkListBox.TInkListBox(RoomList).Options := InkListBox.TInkListBox(RoomList).Options - [lboDrawFocusRect];
  MemberList.Options := MemberList.Options - [lboDrawFocusRect];
  ThreadPane.OnClose := @ThreadClosed;
  ThreadPane.OnConnectionAnswer := @NoticeAnswer;
  ThreadPane.OnLink := @ThreadLink;
  ThreadPane.OnPicture := @ThreadPicture;
  OnRing := @Ring;
  OnLiveGone := @LiveGone;
  OnLiveReady := @LiveReady;
  OnActivate := @FormActivated;
  OnWindowStateChange := @WindowStateChanged;
  // A window restored from minimized is not activated as a form again.
  Application.AddOnActivateHandler(@FormActivated);
  TypingTimer := TTimer.Create(Self);
  TypingTimer.Interval := 2000;
  TypingTimer.OnTimer := @TypingTick;
  // Files dropped on the message box go with the next message
  // (CrossDragDrop: native drag and drop on every desktop, the box lit
  // while a file is held over it).
  DropTarget := TCrossDragDropTarget.Create(Self);
  DropTarget.AcceptedFormats := [cdfFiles];
  DropTarget.OnDropFiles := @ComposerDropFiles;
  DropTarget.OnError := @DropError;
  DropTarget.Control := Composer;
  Go := TMenuItem.Create(Self);
  Go.Caption := 'Go to channel...';
  Go.ShortCut := ShortCut(VK_K, [ssCtrl]);
  Go.OnClick := @GoToRoomClick;
  RoomMenu.Insert(0, Go);
  Go := TMenuItem.Create(Self);
  Go.Caption := 'First unread message';
  Go.ShortCut := ShortCut(VK_U, [ssCtrl]);
  Go.OnClick := @FirstUnreadClick;
  RoomMenu.Insert(1, Go);
  // Suggestions for @name, #room and /command, over the message box.
  // The tray: a menu, and a click opens where the last note came from.
  TrayMenu := TPopupMenu.Create(Self);
  Go := TMenuItem.Create(Self);
  Go.Caption := 'Open Exedra';
  Go.OnClick := @TrayClick;
  TrayMenu.Items.Add(Go);
  Go := TMenuItem.Create(Self);
  Go.Caption := '-';
  TrayMenu.Items.Add(Go);
  Go := TMenuItem.Create(Self);
  Go.Action := ActQuit;
  TrayMenu.Items.Add(Go);
  Tray.PopUpMenu := TrayMenu;
  Tray.OnDblClick := @TrayClick;
  MarkTimer := TTimer.Create(Self);
  MarkTimer.Enabled := False;
  MarkTimer.Interval := 4000;
  MarkTimer.OnTimer := @MarkTick;
  DeleteDmItem := TMenuItem.Create(Self);
  DeleteDmItem.Caption := 'Delete this conversation...';
  DeleteDmItem.OnClick := @DeleteDmClick;
  RoomMenu.Add(DeleteDmItem);
  RoomItem(2, '-', nil);
  // Running the room, before the conversation items.
  I := RoomMenu.IndexOf(LockItem);
  NewRoomItem := RoomItem(I, 'New channel...', @NewRoomClick);
  TopicItem := RoomItem(I + 1, 'Set the topic...', @TopicClick);
  InviteItem := RoomItem(I + 2, 'Invite someone...', @InviteClick);
  KickItem := RoomItem(I + 3, 'Take someone out...', @KickClick);
  LeaveItem := RoomItem(I + 4, 'Leave this channel', @LeaveClick);
  RoomItem(I + 5, '-', nil);
  Suggest := TListBox.Create(Self);
  Suggest.Parent := RoomPanel;
  Suggest.Visible := False;
  Suggest.Width := 360;
  Suggest.OnClick := @SuggestClick;
  LiveRetry := TTimer.Create(Self);
  LiveRetry.Enabled := False;
  LiveRetry.Interval := 250;
  LiveRetry.OnTimer := @LiveRetryTick;
  SuggestTimer := TTimer.Create(Self);
  SuggestTimer.Enabled := False;
  SuggestTimer.Interval := 300;
  SuggestTimer.OnTimer := @SuggestTick;
  Rep := TMenuItem.Create(Self);
  Rep.Caption := 'Report a problem...';
  Rep.OnClick := @ReportClick;
  HelpMenu.Insert(0, Rep);
  Sep := TMenuItem.Create(Self);
  Sep.Caption := '-';
  HelpMenu.Insert(1, Sep);
  // The files attached so far, above the message box; nothing until there is one.
  ComposerBase := ComposerPanel.Height;
  AttachRow := TInkLabel.Create(Self);
  AttachRow.Parent := ComposerPanel;
  AttachRow.Align := alTop;
  AttachRow.AutoSize := False;
  AttachRow.Height := 0;
  AttachRow.OnLinkClick := @AttachRowLink;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  if Instance.Role = firSecondary then
    Exit;
  StripeMemo(Messages);
  SizeExpiryBox(FileExpiryBox);
  RoomList.Color := Mix(clWindow, clWindowText, 0.035);
  ThemePaper := ColorToRGB(clWindow);
  ThemeInk := ColorToRGB(clWindowText);
  ApplyScale;
  // The thin line under the header, a shade of the panel it sits on.
  HeaderRule.Pen.Color := Mix(RoomPanel.Color, InkOf(RoomHeader.Font.Color), 0.2);
  HeaderRule.Brush.Color := HeaderRule.Pen.Color;
  // After the window is up, so the sign-in dialog has something to sit on.
  if Slugs.Count = 0 then
    Application.QueueAsyncCall(@Start, 0);
end;

{ The windows go at once when the program closes.  Requests still in
  flight are waited for after this, as the units shut down, and that can
  take as long as a network timeout. }
procedure TMainForm.DoClose(var CloseAction: TCloseAction);
var
  I: integer;
begin
  inherited DoClose(CloseAction);
  if CloseAction = caNone then
    Exit;
  for I := 0 to Screen.FormCount - 1 do Screen.Forms[I].Hide;
  Application.ProcessMessages;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  I: integer;
begin
  if Instance.Role = firSecondary then
    Exit;
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TTimer then TTimer(Components[I]).Enabled := False;
  Application.RemoveAsyncCalls(Self);
  Application.RemoveOnActivateHandler(@FormActivated);
  ApiForgetAll;
  ApiOnError := nil;
  ApiOnResult := nil;
  ApiOnSignInEnded := nil;
  OnRing := nil;
  OnLiveGone := nil;
  OnLiveReady := nil;
  StopLive;
  for I := 0 to Screen.FormCount - 1 do Screen.Forms[I].Hide;
  // Deliver native hide events before waiting for transports.
  Application.ProcessMessages;
  ApiStopWorker;
  SaveAccount;
  Drafts.Free;
  DmReply.Free;
  EditPayload.Free;
  Commands.Free;
  SuggestNames.Free;
  Shown.Free;
  DmReload.Free;
  Previews.Free;
  NoticeBefore.Free;
  RoomList.RowKeys := nil;
  Slugs.Free;
  Pictures.Free;
  Downloads.Free;
  DownloadPending.Free;
  WipeBytes(MyKey);
  WipeBytes(DmKey);
  WipeText(SentText);
  WipeText(DraftBeforeEdit);
  IconIndex.Free;
  RoomsSeen.Free;
  DmsSeen.Free;
  HereSeen.Free;
  Staff.Free;
  Attached.Free;
  MemberNames.Free;
  Card.Free;
  MyCan.Free;
  MyReactions.Free;
  Accounts.Free;
end;

procedure TMainForm.Start(Data: PtrInt);
begin
  Started := True;
  if (Token = '') and not SignIn then
  begin
    Close;
    Exit;
  end;
  // Who this is: refused when the token was taken back on the profile page.
  RoomHeader.Caption := 'Connecting to ' + Escape(Server) + '...';
  ApiGetAsync('/api/me', @MeDone);
end;

procedure TMainForm.MeDone(Job: TApiJob);
var
  Perm: TJSONEnum;
  Words: string;
begin
  FreeAndNil(MyCan);
  AdminMenu.Visible := False;
  Words := Job.Error;
  if Words = '' then
    with Job.ObjectJSON do
    try
      MyName := Get('name', '');
      MyKeyName := Get('key_name', MyName);
      AutoAway := Get('auto_away', 10);
      // Away as idle from the last time the program ran: back now.
      Idle := Get('away', '') = 'idle';
      if Find('can') is TJSONArray then
      begin
        MyCan.Free;
        MyCan := TStringList.Create;
        for Perm in Arrays['can'] do
          MyCan.Add(Perm.Value.AsString);
      end;
      FreeAndNil(MyReactions);
      if Find('reactions') is TJSONObject then
        MyReactions := TJSONObject(Objects['reactions'].Clone);
    finally
      Free;
    end;
  if (Words = '') and (MyName = '') then
    Words := 'Sign in again, please.';
  if Words <> '' then
  begin
    RoomHeader.Caption := '';
    if Job.Error <> '' then
    begin
      ShowJobError(Job, 'account');
      if not Job.ErrorHandled and (ConnectionFailure(Job.Status) = cfOther) then ConnectionLost(0);
    end
    else
      ConnectionLost(401);
    Exit;
  end;
  MembersItem.Visible := AdminCan(MyCan, 'view-admin');
  ChannelsItem.Visible := AdminCan(MyCan, 'manage-channels');
  PrivateItem.Visible := AdminCan(MyCan, 'manage-private');
  AdminMenu.Visible := MembersItem.Visible or ChannelsItem.Visible or PrivateItem.Visible;
  ApiGetAsync('/api/commands', @CommandsDone);
  // A room saved last time may be gone; the first one in the list will do.
  FallBack := Room <> '';
  OpenRoom(Room);
  RetryBusy := True;
  RetryDue := GetTickCount64 + 45000;
  LiveRetry.Enabled := True;
  ApiGetAsync('/api/rooms', @ChatProbeDone, 0, 'chat-probe');
  PingTimer.Enabled := True;
end;

procedure TMainForm.MembersClick(Sender: TObject);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if not AdminCan(MyCan, 'view-admin') then Exit;
  if MemberAdmin = nil then MemberAdmin := TMembersForm.Create(Self);
  MemberAdmin.Open(MyName, MyCan);
end;

procedure TMainForm.ChannelsClick(Sender: TObject);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if not AdminCan(MyCan, 'manage-channels') then Exit;
  if ChannelAdmin = nil then
  begin
    ChannelAdmin := TChannelsForm.Create(Self);
    ChannelAdmin.OnNewChannel := @NewRoomClick;
    ChannelAdmin.OnChanged := @ChannelsChanged;
  end;
  ChannelAdmin.Open(MyCan);
end;

procedure TMainForm.ChannelsChanged(Sender: TObject);
begin
  RefreshRooms;
  if not InDm then ReadRoomCard;
end;

procedure TMainForm.PrivateClick(Sender: TObject);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if (MyCan = nil) or not SiteCan('manage-private') then
    Exit;
  if Oversight = nil then
  begin
    Oversight := TOversightForm.Create(Self);
    Oversight.OnDeleted := @PrivateDeleted;
  end;
  Oversight.Open;
end;

procedure TMainForm.PrivateDeleted(const Kind, Slug, NameA, NameB: string);
begin
  if (Kind = 'channel') and ((Room = Slug) or (OpeningBusy and (Opening = Slug))) then
  begin
    ClearCurrent;
    OpenRoom('');
  end
  else if (Kind = 'conversation') and ((SameText(MyName, NameA) and SameText(Room, '@' + NameB)) or (SameText(MyName, NameB) and SameText(Room, '@' + NameA))) then
    OpenRoom(Room)
  else
    Sync;
end;

{ The channel on show has closed: another takes its place, and the member is
  told once the ring or answer that brought the news is out of the way. }
procedure TMainForm.ChannelClosed(const Words: string);
begin
  ClearCurrent;
  OpenRoom('');
  ClosedWords := Words;
  Application.QueueAsyncCall(@ShowClosed, 0);
end;

procedure TMainForm.ShowClosed(Data: PtrInt);
var
  Words: string;
begin
  Words := ClosedWords;
  ClosedWords := '';
  if Words = '' then
    Exit;
  if Application.Active and (WindowState <> wsMinimized) then
    NoticeToast.Show(Words)
  else
    Notify('Exedra', Words);
end;

{ An inaccessible channel must not keep its messages or thread on screen. }
procedure TMainForm.ClearCurrent;
begin
  StoreDraft;
  if ThreadPane.Visible then
    ThreadClosed(nil);
  Inc(RoomGen);
  WipeBytes(KeyWrap);
  WipeText(KeyPassword);
  WipeText(KeyAnswer);
  SyncBusy := False;
  SyncAgain := False;
  DmNewsBusy := False;
  Fetching := False;
  OpeningBusy := False;
  EditingId := 0;
  FreeAndNil(EditPayload);
  ThreadAfter := 0;
  AfterOpen := '';
  JumpId := 0;
  Room := '';
  Opening := '';
  Shown.Clear;
  Previews.Clear;
  Messages.Clear;
  Staff.Clear;
  HereSeen.Clear;
  MoreBefore := False;
  WipeBytes(DmKey);
  DmLocked := False;
  TypingTimer.Enabled := False;
  TypingLabel.Caption := '';
  FreeAndNil(Card);
  ShowHeader(-1, 'Exedra', 'Choose a channel.');
  Caption := 'Exedra';
  ShowPeople;
  ShowRoomMenu;
  Composer.ReadOnly := True;
end;

function TMainForm.SignIn(BlankServer: boolean): boolean;
begin
  with TSignInForm.Create(Self) do
  try
    if not BlankServer and (Server <> '') then
      ServerEdit.Text := Server;
    Result := ShowModal = mrOk;
  finally
    Free;
  end;
  if Result then
  begin
    ApiResetSignInFailure;
    SaveAccount;
  end;
end;

procedure TMainForm.SaveAccount;
var
  I: integer;
begin
  // Never over a file that has not been read: a start cut short would
  // wipe the account.
  if not SettingsRead then
    Exit;
  with TIniFile.Create(ConfigFile) do
  try
    WriteString('account', 'server', Server);
    WriteString('account', 'token', Token);
    WriteString('account', 'room', Room);
    WriteInteger('view', 'scale', TextScale);
    EraseSection('accounts');
    for I := 0 to Accounts.Count - 1 do
      if Accounts.ValueFromIndex[I] <> '' then
        WriteString('accounts', Accounts.Names[I], Accounts.ValueFromIndex[I]);
    UpdateFile;
  finally
    Free;
  end;
  OwnerOnly;
end;

function TMainForm.LastId: integer;
begin
  Result := 0;
  if Shown.Count > 0 then
    Result := TJSONObject(Shown.Items[Shown.Count - 1]).Get('id', 0);
end;

{ The newest messages of a room, then everything else through Sync. }
procedure TMainForm.OpenRoom(const Wanted: string);
begin
  if ChatOff then Exit;
  NoticeBar.Hide('send');
  if EditingId > 0 then
    StopEdit;
  TypingTimer.Enabled := False;
  TypingLabel.Caption := '';
  if Wanted <> Room then
  begin
    FreeAndNil(Card);
    Staff.Clear;
    HereSeen.Clear;
    ShowPeople;
  end;
  // A thread belongs to the room it was opened in, and so does a draft.
  if ThreadPane.Visible and (Wanted <> Room) then
    ThreadClosed(nil);
  if Wanted <> Room then
    StoreDraft
  else if (Room <> '') and CanTalk then
    // Read afresh: what is being typed stays.
    Drafts.Values[Room] := StringReplace(Composer.Text, LineEnding, #1, [rfReplaceAll]);
  EditingId := 0;
  // Answers on their way for the room being left are dropped by their tag.
  Inc(RoomGen);
  WipeBytes(KeyWrap);
  WipeText(KeyPassword);
  WipeText(KeyAnswer);
  SyncBusy := False;
  SyncAgain := False;
  Fetching := False;
  DmNewsBusy := False;
  DmCheckDue := False;
  DmReadDue := False;
  Opening := Wanted;
  OpeningBusy := True;
  ActSend.Enabled := False;
  AttachButton.Enabled := False;
  if Wanted.StartsWith('@') then
    ApiGetAsync('/api/key?' + Query(['name', Copy(Wanted, 2, MaxInt)]), @DmKeyDone, RoomGen)
  else if Wanted = '' then
    // No room chosen yet: the first of the member's rooms.
    ApiGetAsync('/api/rooms', @FirstRoomDone, RoomGen)
  else
    ApiGetAsync('/api/messages?' + Query(['room', Wanted]), @RoomDone, RoomGen);
end;

procedure TMainForm.FirstRoomDone(Job: TApiJob);
var
  List: TJSONArray;
begin
  if Job.Tag <> RoomGen then
    Exit;
  if Job.Error <> '' then
  begin
    RoomFailed(Job.Error, Job.ErrorHandled);
    Exit;
  end;
  List := Job.ArrayJSON;
  try
    RoomsSeen.Free;
    RoomsSeen := List.Clone as TJSONArray;
    ShowRooms;
    if List.Count > 0 then
      Opening := TJSONObject(List[0]).Get('slug', '');
  finally
    List.Free;
  end;
  if Opening = '' then
  begin
    ClearCurrent;
    RefreshRooms;
    ShowList(False);
  end
  else
    ApiGetAsync('/api/messages?' + Query(['room', Opening]), @RoomDone, RoomGen);
end;

{ The room's newest messages are in: it is the one on show from here. }
procedure TMainForm.RoomDone(Job: TApiJob);
var
  Answer: TJSONObject;
  List: TJSONArray;
  I: integer;
begin
  if Job.Tag <> RoomGen then
    Exit;
  if Job.Error <> '' then
  begin
    // A room saved last time may be gone; the first in the list will do.
    if FallBack and not Job.ErrorHandled then
    begin
      FallBack := False;
      OpenRoom('');
    end
    else
      RoomFailed(Job.Error, Job.ErrorHandled);
    Exit;
  end;
  FallBack := False;
  OpeningBusy := False;
  Answer := Job.ObjectJSON;
  try
    Room := Opening;
    List := Answer.Arrays['messages'];
    Shown.Clear;
    Previews.Clear;
    // Newest first from the server.
    for I := List.Count - 1 downto 0 do
      if TJSONObject(List[I]).Get('parent', 0) = 0 then
        Shown.Add(TJSONObject(List[I]).Clone);
    MoreBefore := List.Count >= 50;
    Since := Answer.Get('rev', int64(0)) - RevSlack;
    // The New messages line goes over the first message by someone else
    // that was not read before this visit, and stays there while the room
    // is on show.
    LastReadId := Answer.Get('last_read', 0);
    DividerId := 0;
    for I := 0 to Shown.Count - 1 do
      if (TJSONObject(Shown[I]).Get('id', 0) > LastReadId) and (TJSONObject(Shown[I]).Get('name', '') <> MyName) then
      begin
        DividerId := TJSONObject(Shown[I]).Get('id', 0);
        Break;
      end;
  finally
    Answer.Free;
  end;
  ReadStaff;
  Render;
  ReadRoomCard;
  ShowRoomMenu;
  FillPages := 0;
  FillUp;
  Sync;
  ShowList(False);
  TakeDraft;
  AfterOpened;
end;

{ Words waiting for a conversation that did not open: they are not sent,
  and the member is told so. }
procedure TMainForm.DropAfterOpen;
var
  Who: string;
begin
  if AfterOpen = '' then
    Exit;
  Who := AfterOpenFor;
  WipeText(AfterOpen);
  AfterOpen := '';
  AfterOpenFor := '';
  NoticeBar.Show('Your message to ' + Who + ' was not sent: that conversation did not open.', mtWarning, [], 'afteropen');
end;

{ Keep the list on the room whose messages are still showing. }
procedure TMainForm.RoomFailed(const Words: string; Handled: boolean);
begin
  OpeningBusy := False;
  DropAfterOpen;
  if ChatOff then Exit;
  RoomList.ItemIndex := Slugs.IndexOf(Room);
  ShowRoomMenu;
  if Handled then Exit;
  if Room = '' then
    RoomHeader.Caption := Escape(Words) + ' Reload (F5) tries again.'
  else
    NoticeBar.Show(Words, mtError, [], 'roomfailed');
end;

{ A short room cannot scroll up to ask for more: older pages are read
  until it can, ten at most. }
procedure TMainForm.FillUp;
begin
  if MoreBefore and (Messages.ContentHeight <= Messages.ClientHeight) and (FillPages < 10) then
  begin
    Inc(FillPages);
    LoadOlder;
  end;
end;

{ What was waiting for the room or conversation to open. }
procedure TMainForm.AfterOpened;
var
  Words: string;
begin
  if ThreadAfter > 0 then
  begin
    OpenThreadOn(ThreadAfter);
    ThreadAfter := 0;
  end;
  // words typed with /msg go to the member they were typed for, and only
  // there: another conversation opening first does not get them
  if (AfterOpen <> '') and not (InDm and SameText(Room, AfterOpenFor)) then
    DropAfterOpen;
  if (AfterOpen <> '') and InDm then
  begin
    Words := AfterOpen;
    AfterOpen := '';
    AfterOpenFor := '';
    try
      SendDm(Words);
    except
      on E: Exception do
        ShowError(E, 'afteropened');
    end;
  end;
  if JumpId > 0 then
    JumpStep;
end;

{ What was typed in the room being left waits for the next visit; files
  attached there do not follow (they stay uploaded for a while, and a locked
  conversation's would be sealed with the wrong key). }
procedure TMainForm.StoreDraft;
begin
  Inc(UploadGen);
  Uploading := 0;
  ClearAnswer;
  SuggestTimer.Enabled := False;
  SuggestQuery := '';
  SuggestNames.Clear;
  Inc(SuggestGen);
  // What a quiet composer shows is the server's reason, not a draft; and
  // while a message is being edited, the draft is the one put aside.
  if (Room <> '') and CanTalk then
    if EditingId > 0 then
      Drafts.Values[Room] := StringReplace(DraftBeforeEdit, LineEnding, #1, [rfReplaceAll])
    else
      Drafts.Values[Room] := StringReplace(Composer.Text, LineEnding, #1, [rfReplaceAll]);
  Composer.Clear;
  ClearAttached;
  HideSuggest;
end;

procedure TMainForm.TakeDraft;
begin
  // Not typing, so the others are not told.
  LastTyping := GetTickCount64;
  // Where this member cannot post, the box says why and takes nothing.
  Composer.ReadOnly := not CanTalk;
  if CanTalk then
  begin
    Composer.Font.Color := clDefault;
    Composer.Text := StringReplace(Drafts.Values[Room], #1, LineEnding, [rfReplaceAll]);
  end
  else
  begin
    Composer.Font.Color := clGrayText;
    Composer.Text := WhyNot;
  end;
  Composer.SelStart := Length(Composer.Text);
  FocusComposer;
end;

{ The line over the messages: the room's icon, its name and its topic. }
procedure TMainForm.ShowHeader(Pic: integer; const Title, Note: string);
var
  I: integer;
begin
  ClearIconUse(4);
  for I := 0 to IconIndex.Count - 1 do
    with TDeskIconEntry(IconIndex.Objects[I]) do
      if Slot = Pic then Users := Users or 4;
  HeadPic := Pic;
  HeadTitle := Title;
  HeadNote := Note;
  RoomHeader.Caption := HeaderHtml(Pic, Title, Note, RoomPanel.Color, InkOf(RoomHeader.Font.Color), NarrowMode);
end;

{ The avatar of the member a conversation is with, as the room list has it. }
function TMainForm.DmAvatar(const Who: string): string;
var
  Item: TJSONEnum;
begin
  Result := '';
  for Item in DmsSeen do
    if TJSONObject(Item.Value).Get('name', '') = Who then
      Result := TJSONObject(Item.Value).Get('avatar', '');
end;

{ The room's own name and topic, whether or not it is in the member's list. }
procedure TMainForm.ReadRoomCard;
begin
  ApiGetAsync('/api/room?' + Query(['slug', Room]), @CardDone, RoomGen);
end;

{ The card is in: the header, the menus, and the composer quiet when the
  member may not post here (what was typed meanwhile is kept as a draft). }
procedure TMainForm.CardDone(Job: TApiJob);
var
  Could: boolean;
begin
  if (Job.Tag <> RoomGen) or InDm then
    Exit;
  // The server says 404 for a channel this member may not read, and for
  // everything when the chat is off: the list of rooms tells which.
  if Job.Status = 404 then
  begin
    ApiGetAsync('/api/rooms', @RoomGoneDone, RoomGen, 'room-gone');
    Exit;
  end;
  if Job.Status = 403 then
  begin
    ChannelClosed('You are no longer in #' + Room + '.');
    Exit;
  end;
  if Job.Error <> '' then
    Exit;
  FreeAndNil(Card);
  Card := Job.ObjectJSON;
  ShowHeader(IconFor(Card.Get('avatar', ''), '#', True), '#' + Card.Get('title', Room), Card.Get('topic', ''));
  Caption := '#' + Card.Get('title', Room) + ' - Exedra';
  Could := CanTalk;
  ShowRoomMenu;
  if Could and not CanTalk then
  begin
    Drafts.Values[Room] := StringReplace(Composer.Text, LineEnding, #1, [rfReplaceAll]);
    TakeDraft;
  end;
end;

{ The room's card answered 404.  With the chat still there, the channel is
  closed to this member: its messages come off the screen and another room
  is opened.  With the chat gone too, that is said instead. }
procedure TMainForm.RoomGoneDone(Job: TApiJob);
begin
  if Job.Status = 404 then
    ChatProbeDone(Job)
  else if (Job.Error = '') and (Job.Tag = RoomGen) and not InDm then
    ChannelClosed('#' + Room + ' is not open to you any more.');
end;

{ The 50 before the oldest on show, put above it; the reader stays where
  they were. }
procedure TMainForm.LoadOlder;
begin
  if (Shown.Count = 0) or Fetching then
    Exit;
  Fetching := True;
  if InDm then
    // Oldest first, the way /api/dm answers.
    ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daBefore, TJSONObject(Shown[0]).Get('id', 0)), @OlderDone, RoomGen)
  else
    ApiGetAsync('/api/messages?' + Query(['room', Room, 'before', IntToStr(TJSONObject(Shown[0]).Get('id', 0))]), @OlderDone, RoomGen);
end;

procedure TMainForm.OlderDone(Job: TApiJob);
var
  Answer: TJSONData;
  List: TJSONArray;
  I, Added: integer;
begin
  // For a room since left: that room's Fetching was put back already.
  if Job.Tag <> RoomGen then
    Exit;
  Fetching := False;
  if Job.Error <> '' then
  begin
    // Asked again at the next scroll to the top; a jump gives up.
    if JumpId > 0 then
      ShowJobError(Job, 'olderdone');
    JumpId := 0;
    Exit;
  end;
  Added := 0;
  Answer := Job.JSON;
  try
    if InDm then
    begin
      List := TJSONArray(Answer);
      for I := List.Count - 1 downto 0 do
      begin
        Shown.Insert(0, Readable(TJSONObject(List[I])));
        Inc(Added);
      end;
    end
    else
    begin
      List := TJSONObject(Answer).Arrays['messages'];
      // Newest first from the server, so each goes in at the top.
      for I := 0 to List.Count - 1 do
        if TJSONObject(List[I]).Get('parent', 0) = 0 then
        begin
          Shown.Insert(0, TJSONObject(List[I]).Clone);
          Inc(Added);
        end;
    end;
    if InDm then
      MoreBefore := List.Count >= 100
    else
      MoreBefore := List.Count >= 50;
  finally
    Answer.Free;
  end;
  Messages.BeginUpdate;
  try
    for I := 0 to Added - 1 do
      Messages.InsertBlock(I, EntryHtml(I), itfHTML, EntryColor(I));
    // The one that was first may now go under the same name.
    if Added < Shown.Count then
      PutEntry(Added);
  finally
    Messages.EndUpdate;
  end;
  if JumpId > 0 then
    JumpStep
  else
    FillUp;
end;

{ Asks what changed since the last time, and shows it. }
procedure TMainForm.Sync;
var
  Reading: string;
begin
  if SignInEnded or ChatOff then Exit;
  // One at a time; a second ask while one is out is answered by another
  // sync once that one is in.
  if SyncBusy then
  begin
    SyncAgain := True;
    Exit;
  end;
  if OpeningBusy then
    Exit;
  if Room = '' then
  begin
    RefreshRooms;
    Exit;
  end;
  SyncBusy := True;
  SyncNoticeSerial := NoticeSerial;
  Reading := '0';
  if Application.Active and (WindowState <> wsMinimized) then
    Reading := IntToStr(LastId);
  if InDm then
    ApiGetAsync('/api/sync?' + Query(['since', IntToStr(Since), 'rooms', '1', 'live', LiveId]), @SyncDone, RoomGen)
  else
    ApiGetAsync('/api/sync?' + Query(['room', Room, 'since', IntToStr(Since), 'rooms', '1', 'here', '1', 'live', LiveId, 'read', Reading,
      'thread', IntToStr(ThreadPane.SyncId)]), @SyncDone, RoomGen);
end;

procedure TMainForm.SyncDone(Job: TApiJob);
var
  Again: boolean;
begin
  if Job.Tag <> RoomGen then
    Exit;
  SyncBusy := False;
  Again := SyncAgain;
  SyncAgain := False;
  // From a room since left, or a failure: nothing to show; the next ring
  // or ping asks again.
  if (Job.Tag = RoomGen) and (Job.Error = '') then
    ApplySync(Job.ObjectJSON, SyncNoticeSerial);
  if Again then
    Sync;
end;

{ Answer's changes put into Shown and the memo; Answer is freed here. }
procedure TMainForm.ApplySync(Answer: TJSONObject; NoticeAtRequest: integer);
var
  Msg: TJSONObject;
  Item: TJSONEnum;
  I, J, Id, Newest, FirstNew: integer;
  Edited: TStringList;   // the places in Shown that changed
  Fresh: TJSONArray;     // new messages, in order of id whatever order the changes came in
  Overflow: boolean;     // more changes than one answer carries
  Listed, WasListed: boolean;
begin
  // Private membership can end after a kick or a channel deletion.
  if not InDm and (Card <> nil) and Card.Get('private', False) and (Answer.Find('rooms') is TJSONArray) then
  begin
    Listed := False;
    for Item in Answer.Arrays['rooms'] do
      if TJSONObject(Item.Value).Get('slug', '') = Room then
        Listed := True;
    // The list leaves out an archived channel, which one may still read, so
    // the card decides.
    if not Listed then
      ReadRoomCard;
  end;
  // An emptied conversation disappears from the sidebar, including offline deletions.
  if InDm and (Shown.Count > 0) and (Answer.Find('dms') is TJSONArray) then
  begin
    WasListed := False;
    for Item in DmsSeen do
      if SameText(TJSONObject(Item.Value).Get('name', ''), Copy(Room, 2, MaxInt)) then
        WasListed := True;
    Listed := False;
    for Item in Answer.Arrays['dms'] do
      if SameText(TJSONObject(Item.Value).Get('name', ''), Copy(Room, 2, MaxInt)) then
        Listed := True;
    if WasListed and not Listed then
    begin
      DmsSeen.Free;
      DmsSeen := Answer.Arrays['dms'].Clone as TJSONArray;
      Answer.Free;
      OpenRoom(Room);
      Exit;
    end;
  end;
  Edited := TStringList.Create;
  Fresh := TJSONArray.Create;
  try
    try
      Newest := LastId;
      FirstNew := Shown.Count;
      Overflow := Answer.Get('more', False);
      for Item in ArrayOf(Answer, 'messages') do
      begin
        Msg := TJSONObject(Item.Value);
        Id := Msg.Get('id', 0);
        if InDm or (Msg.Get('parent', 0) <> 0) then
          Continue;
        if Id > Newest then
        begin
          J := Fresh.Count;
          while (J > 0) and (TJSONObject(Fresh[J - 1]).Get('id', 0) > Id) do
            Dec(J);
          Fresh.Insert(J, Msg.Clone);
        end
        else
          for I := 0 to Shown.Count - 1 do
            if TJSONObject(Shown[I]).Get('id', 0) = Id then
            begin
              Shown[I] := Msg.Clone;
              Edited.Add(IntToStr(I));
              Break;
            end;
      end;
      while Fresh.Count > 0 do
        Shown.Add(Fresh.Extract(0));
      if Answer.Find('rooms') <> nil then
      begin
        NotifyRooms(Answer.Arrays['rooms'], NoticeAtRequest);
        RoomsSeen.Free;
        RoomsSeen := Answer.Arrays['rooms'].Clone as TJSONArray;
      end;
      if Answer.Find('dms') <> nil then
      begin
        DmsSeen.Free;
        DmsSeen := Answer.Arrays['dms'].Clone as TJSONArray;
      end;
      if Answer.Find('here') <> nil then
      begin
        HereSeen.Free;
        HereSeen := Answer.Arrays['here'].Clone as TJSONArray;
      end;
      ShowRooms;
      ShowPeople;
      for Item in ArrayOf(Answer, 'typing') do
        if not InDm and (Item.Value is TJSONString) then
          SaidTyping(Item.Value.AsString);
      ThreadPane.MergeSync(Answer);
      Since := Answer.Get('rev', Since + RevSlack) - RevSlack;
    finally
      Answer.Free;
    end;
    // An edit, a reaction, a deletion: that entry and the one under it,
    // which may show the name again.
    for I := 0 to Edited.Count - 1 do
    begin
      PutEntry(StrToInt(Edited[I]));
      if StrToInt(Edited[I]) + 1 < FirstNew then
        PutEntry(StrToInt(Edited[I]) + 1);
    end;
    if Shown.Count > FirstNew then
      ShowNew(FirstNew);
    ShowSeen;
  finally
    Fresh.Free;
    Edited.Free;
  end;
  // Two hundred changes at once is more than one answer tells about in
  // order; the room is read afresh rather than guessed at.
  if Overflow and not InDm then
    OpenRoom(Room);
end;

{ The index of a picture in Icons, fetched the first time; until it is
  here, and for those without one, a letter (Letter) or -1. }
procedure TMainForm.ClearIconUse(Use: byte);
var
  I: integer;
begin
  for I := 0 to IconIndex.Count - 1 do
    with TDeskIconEntry(IconIndex.Objects[I]) do Users := Users and not Use;
end;

function TMainForm.IconFor(const Url, Who: string; Letter: boolean): integer;
const
  MaxIcons = 2048;  // small pictures: about 4 KB each
var
  I, J, Oldest: integer;
  Key: string;
  Pic: TBitmap;
  Entry: TDeskIconEntry;
begin
  Result := -1;
  if Icons.Count = 0 then
  begin
    Pic := LetterIcon('?', Icons.Width);
    try
      Icons.Add(Pic, nil);
    finally
      Pic.Free;
    end;
  end;
  Key := Url;
  if Key = '' then
  begin
    if not Letter then Exit;
    Key := 'letter:' + Who;
  end;
  I := IconIndex.IndexOf(Key);
  if I < 0 then
  begin
    // Slots stay fixed while rows refer to them.
    Oldest := -1;
    if Icons.Count >= MaxIcons then
    begin
      for J := 0 to IconIndex.Count - 1 do
        if TDeskIconEntry(IconIndex.Objects[J]).Users = 0 then
          if (Oldest < 0) or (TDeskIconEntry(IconIndex.Objects[J]).Used < TDeskIconEntry(IconIndex.Objects[Oldest]).Used) then Oldest := J;
      if Oldest < 0 then
      begin
        if Letter then Result := 0;
        Exit;
      end;
    end;
    Entry := TDeskIconEntry.Create;
    Inc(IconSerial);
    Entry.Serial := IconSerial;
    if Oldest < 0 then Entry.Slot := Icons.Count
    else
    begin
      Entry.Slot := TDeskIconEntry(IconIndex.Objects[Oldest]).Slot;
      IconIndex.Delete(Oldest);
    end;
    Pic := TBitmap.Create;
    try
      Pic.SetSize(Icons.Width, Icons.Height);
      Pic.Transparent := True;
      Pic.TransparentColor := clBlack;
      Pic.Canvas.Brush.Color := clBlack;
      Pic.Canvas.FillRect(0, 0, Pic.Width, Pic.Height);
      if Entry.Slot = Icons.Count then Icons.Add(Pic, nil)
      else
        Icons.Replace(Entry.Slot, Pic, nil);
    finally
      Pic.Free;
    end;
    I := IconIndex.AddObject(Key, Entry);
  end;
  Entry := TDeskIconEntry(IconIndex.Objects[I]);
  if IconUse = 0 then Entry.Users := Entry.Users or 4
  else
    Entry.Users := Entry.Users or IconUse;
  Inc(IconClock);
  Entry.Used := IconClock;
  if not Entry.Ready and not Entry.Pending and (GetTickCount64 >= Entry.RetryAt) then
  begin
    if Url = '' then
    begin
      Pic := LetterIcon(Who, Icons.Width);
      try
        Icons.Replace(Entry.Slot, Pic, nil);
        Entry.Ready := True;
      finally
        Pic.Free;
      end;
    end
    else
    begin
      Entry.Pending := Fetch(Url, @IconArrived, False, Entry.Serial);
      if not Entry.Pending then Entry.RetryAt := GetTickCount64 + PictureRetryDelay;
    end;
  end;
  if Entry.Ready then Result := Entry.Slot
  else if Letter then Result := IconFor('', Who, True);
end;

procedure TMainForm.IconArrived(const Path: string; Bytes: TBytes; FetchTag: integer);
var
  I: integer;
  Pic: TBitmap;
  Entry: TDeskIconEntry;
begin
  I := IconIndex.IndexOf(Path);
  if I < 0 then Exit;
  Entry := TDeskIconEntry(IconIndex.Objects[I]);
  if FetchTag <> Entry.Serial then Exit;
  Entry.Pending := False;
  Pic := IconFromBytes(Bytes, Icons.Width);
  if Pic = nil then
  begin
    Entry.RetryAt := GetTickCount64 + PictureRetryDelay;
    Exit;
  end;
  try
    Icons.Replace(Entry.Slot, Pic, nil);
    Entry.Ready := True;
  finally
    Pic.Free;
  end;
  ShowRooms;
  ShowPeople;
end;

{ Channels, other rooms and private conversations, each under a heading;
  a heading's slug is empty, a conversation's is @name. }
procedure TMainForm.ShowRooms;

  procedure Heading(const Text: string);
  begin
    // A blank line keeps the sections apart; it has no slug, like the heading.
    if RoomList.Items.Count > 0 then
    begin
      RoomList.Items.Add('');
      Slugs.Add('');
    end;
    RoomList.Items.Add(SectionHtml(Text, RoomList.Color, InkOf(RoomList.Font.Color)));
    Slugs.Add('');
  end;

  procedure Line(const Slug, Html: string; Pic: integer);
  var
    Front: string;
  begin
    Front := '';
    if Pic >= 0 then
      Front := '<img src="' + IntToStr(Pic) + '" style="vertical-align: middle">&nbsp;';
    RoomList.Items.Add(Front + Html);
    Slugs.Add(Slug);
    if Slug = Room then
      RoomList.ItemIndex := Slugs.Count - 1;
  end;

  procedure Rooms(Channels, Locked: boolean; const Title: string);
  var
    Item: TJSONEnum;
    R: TJSONObject;
    First, Keep: boolean;
  begin
    First := True;
    for Item in RoomsSeen do
    begin
      R := TJSONObject(Item.Value);
      // Public channels, other public rooms (shelves), and every private
      // room whatever its kind.
      if Locked then
        Keep := R.Get('private', False)
      else
        Keep := not R.Get('private', False) and ((R.Get('kind', '') = 'channel') = Channels);
      if not Keep then
        Continue;
      if First then
        Heading(Title);
      First := False;
      Line(R.Get('slug', ''), RoomHtml(R, RoomList.Color, InkOf(RoomList.Font.Color)), IconFor(R.Get('avatar', ''), '#', True));
      if R.Get('slug', '') = Room then
      begin
        ShowHeader(IconFor(R.Get('avatar', ''), '#', True), '#' + R.Get('title', Room), R.Get('topic', ''));
        Caption := '#' + R.Get('title', Room) + ' - Exedra';
      end;
    end;
  end;

var
  Item: TJSONEnum;
  D: TJSONObject;
  Title, SelectedSlug: string;
  FirstShown, Unread: integer;
begin
  FirstShown := RoomList.TopIndex;
  SelectedSlug := '';
  if RoomList.Focused and (RoomList.ItemIndex >= 0) and (RoomList.ItemIndex < Slugs.Count) then
    SelectedSlug := Slugs[RoomList.ItemIndex];
  RoomList.Items.BeginUpdate;
  try
    RoomList.Items.Clear;
    ClearIconUse(1);
    IconUse := 1;
    Slugs.Clear;
    Rooms(True, False, 'CHANNELS');
    Rooms(False, False, 'OTHER CHANNELS');
    Rooms(False, True, 'PRIVATE CHANNELS');
    if DmsSeen.Count > 0 then
      Heading('PRIVATE MESSAGES');
    for Item in DmsSeen do
    begin
      D := TJSONObject(Item.Value);
      Title := Escape(D.Get('name', ''));
      if D.Get('unread', 0) > 0 then
        Title := '<b>' + Title + '</b> ' + CountBadge(D.Get('unread', 0));
      Title := StatusDot(KnownStatus(D.Get('name', '')), Red(ColorToRGB(RoomList.Color)) < 128) + Title;
      Line('@' + D.Get('name', ''), Title, IconFor(D.Get('avatar', ''), D.Get('name', ''), True));
    end;
  finally
    IconUse := 0;
    RoomList.Items.EndUpdate;
  end;
  if (FirstShown >= 0) and (FirstShown < RoomList.Items.Count) then
    RoomList.TopIndex := FirstShown;
  if (SelectedSlug <> '') and (Slugs.IndexOf(SelectedSlug) >= 0) then
    RoomList.ItemIndex := Slugs.IndexOf(SelectedSlug);
  Unread := 0;
  for Item in RoomsSeen do
    Inc(Unread, RoomUnread(TJSONObject(Item.Value)));
  for Item in DmsSeen do
    Inc(Unread, TJSONObject(Item.Value).Get('unread', 0));
  ShowUnread(Unread);
end;

function TMainForm.KnownStatus(const Who: string): TMemberStatus;
var
  Item: TJSONEnum;
begin
  Result := msUnknown;
  for Item in HereSeen do
    if SameText(TJSONObject(Item.Value).Get('name', ''), Who) then
      Exit(MemberStatus(TJSONObject(Item.Value), True));
  for Item in Staff do
    if SameText(TJSONObject(Item.Value).Get('name', ''), Who) then
      Exit(MemberStatus(TJSONObject(Item.Value)));
  for Item in DmsSeen do
    if SameText(TJSONObject(Item.Value).Get('name', ''), Who) then
      Exit(MemberStatus(TJSONObject(Item.Value)));
end;

procedure TMainForm.ShowPeople;

  procedure Person(P: TJSONObject; const Extra: string; Here: boolean);
  var
    Html: string;
    Status: TMemberStatus;
  begin
    Html := '<img src="' + IntToStr(IconFor(P.Get('avatar', ''), P.Get('name', ''), True)) + '" style="vertical-align: middle">&nbsp;';
    Status := MemberStatus(P, Here);
    if not Here then
      Status := KnownStatus(P.Get('name', ''));
    Html := Html + StatusDot(Status, Red(ColorToRGB(MemberList.Color)) < 128) + Escape(P.Get('name', ''));
    if Status = msAway then
      Html := Html + ' <font color="' + Hex(Muted(MemberList.Color, InkOf(MemberList.Font.Color))) + '"><small><i>away</i></small></font>';
    MemberList.Items.Add(Html + Extra);
    MemberNames.Add(P.Get('name', ''));
  end;

var
  Item: TJSONEnum;
  P: TJSONObject;
  Roles, SelectedName: string;
  FirstShown: integer;
begin
  // Not beside a private conversation or an open thread.
  MemberList.Visible := ActPeople.Checked and not InDm and not ThreadPane.Visible and not NarrowMode;
  if MemberList.Visible and not Splitter2.Visible then
  begin
    Splitter2.Visible := True;
    Splitter2.Left := MemberList.Left - Splitter2.Width;
  end;
  Splitter2.Visible := MemberList.Visible;
  if not MemberList.Visible then
  begin
    ClearIconUse(2);
    Exit;
  end;
  FirstShown := MemberList.TopIndex;
  SelectedName := '';
  if (MemberList.ItemIndex >= 0) and (MemberList.ItemIndex < MemberNames.Count) then
    SelectedName := MemberNames[MemberList.ItemIndex];
  MemberList.Items.BeginUpdate;
  try
    MemberList.Items.Clear;
    ClearIconUse(2);
    IconUse := 2;
    MemberNames.Clear;
    MemberList.Items.Add(SectionHtml('HERE NOW &middot; ' + IntToStr(HereSeen.Count), MemberList.Color, InkOf(MemberList.Font.Color)));
    MemberNames.Add('');
    for Item in HereSeen do
      Person(TJSONObject(Item.Value), '', True);
    if Staff.Count > 0 then
    begin
      MemberList.Items.Add('');
      MemberNames.Add('');
      MemberList.Items.Add(SectionHtml('IN THIS CHANNEL', MemberList.Color, InkOf(MemberList.Font.Color)));
      MemberNames.Add('');
    end;
    for Item in Staff do
    begin
      P := TJSONObject(Item.Value);
      Roles := StringReplace(P.Get('roles', ''), ',', ', ', [rfReplaceAll]);
      if P.Get('owner', False) then
        Roles := Trim('owner ' + Roles);
      if Roles <> '' then
        Roles := ' <font color="' + Hex(Muted(MemberList.Color, InkOf(MemberList.Font.Color))) + '"><small>' + Escape(Roles) + '</small></font>';
      Person(P, Roles, False);
    end;
  finally
    IconUse := 0;
    MemberList.Items.EndUpdate;
  end;
  if (SelectedName <> '') and (MemberNames.IndexOf(SelectedName) >= 0) then
    MemberList.ItemIndex := MemberNames.IndexOf(SelectedName);
  if (FirstShown >= 0) and (FirstShown < MemberList.Items.Count) then
    MemberList.TopIndex := FirstShown;
end;

{ Every message on show, after opening a room. }
procedure TMainForm.Render;
begin
  Messages.Clear;
  Messages.BeginUpdate;
  try
    ShowNew(0);
    // Not an entry of Shown: the first message that comes replaces it (Sync).
    if Shown.Count = 0 then
      Messages.AppendBlock(EmptyHtml('Nothing said here yet. Say hello.'), itfHTML);
  finally
    Messages.EndUpdate;
  end;
end;

{ Shown[First] and on, added at the bottom.  Entry I of Messages is
  always Shown[I]. }
procedure TMainForm.ShowNew(First: integer);
var
  I: integer;
  Was: boolean;
begin
  // The empty-room note goes before the first message takes its place.
  if (First = 0) and (Messages.Count > 0) and (Shown.Count > 0) then
    Messages.Clear;
  Was := Filling;
  Filling := True;
  try
    for I := First to Shown.Count - 1 do
      Messages.AppendBlock(EntryHtml(I), itfHTML, EntryColor(I));
  finally
    Filling := Was;
  end;
end;

function TMainForm.EntryHtml(I: integer): string;
var
  Before, Msg: TJSONObject;
begin
  Before := nil;
  if I > 0 then
    Before := TJSONObject(Shown[I - 1]);
  Msg := TJSONObject(Shown[I]);
  Result := '';
  if NewDay(Before, Msg) then
    Result := DayHtml(Msg);
  if (DividerId > 0) and (Msg.Get('id', 0) = DividerId) then
    Result := Result + NewMessagesHtml;
  Result := Result + MessageHtml(Msg, Continues(Before, Msg) and (Result = ''), Previews.IsOpen(Msg), Previews.FocusId = Msg.Get('id', 0));
  if InDm and (Msg.Get('id', 0) = SeenId) then
    Result := Result + '<p class="edited">Seen</p>';
end;

function TMainForm.EntryColor(I: integer): TColor;
begin
  Result := clNone;
  // A mention: a wash of the selection color, so it reads in any theme;
  // a message just jumped to, a stronger one for a moment.
  if TJSONObject(Shown[I]).Get('mentions_me', False) then
    Result := Mix(Messages.Color, clHighlight, 0.18);
  if (MarkId > 0) and (TJSONObject(Shown[I]).Get('id', 0) = MarkId) then
    Result := Mix(Messages.Color, clHighlight, 0.3);
end;

procedure TMainForm.PutEntry(I: integer);
begin
  Messages.ReplaceBlock(I, EntryHtml(I), itfHTML, EntryColor(I));
end;

procedure TMainForm.MessagesScroll(Sender: TObject);
begin
  // Not while entries are being put in: an append lays the memo out at the
  // top for a moment, and older ones coming in then would shift Shown under
  // the loop that is filling it.
  if (Messages.ScrollY = 0) and MoreBefore and not Filling and not Fetching then
    LoadOlder;
end;

procedure TMainForm.Ring(const Kind, RingRoom, Who: string; Deleted, Edited: integer; Gone: boolean);
begin
  if (Kind = 'dm') and (Edited > 0) then
  begin
    if InDm and (SameText(Who, Copy(Room, 2, MaxInt)) or SameText(Who, MyName)) then
      RefreshDm(Edited);
    Exit;
  end;
  if (Kind = 'typing') or (Kind = 'dmtyping') then
  begin
    if ((Kind = 'typing') and not InDm and (RingRoom = Room)) or ((Kind = 'dmtyping') and InDm and SameText(Who, Copy(Room, 2, MaxInt))) then
      SaidTyping(Who);
    Exit;
  end;
  if Kind = 'names' then
  begin
    ApiGetAsync('/api/me', @MeDone);
    Exit;
  end;
  if Kind = 'gone' then
  begin
    if (RingRoom = Room) or (OpeningBusy and (RingRoom = Opening)) then
      ChannelClosed('This channel was deleted.');
    RefreshRooms;
    Exit;
  end;
  if (Kind = 'dm') and (Gone or (Deleted > 0)) then
  begin
    if InDm and (SameText(Who, Copy(Room, 2, MaxInt)) or SameText(Who, MyName)) then
    begin
      if Gone then
      begin
        if OpeningBusy then
          OpenRoom(Opening)
        else
          OpenRoom(Room);
      end
      else
        RemoveDmMessage(Deleted);
    end
    else if OpeningBusy and Opening.StartsWith('@') and (SameText(Who, Copy(Opening, 2, MaxInt)) or SameText(Who, MyName)) then
      OpenRoom(Opening);
    RefreshRooms;
    Exit;
  end;
  // A ring is only a nudge: when the server cannot be reached just now,
  // the next ping catches up, and no dialog is owed for it.
  if (Kind = 'me') and (not Application.Active or (WindowState = wsMinimized)) then
  begin
    if not NoticePending then
    begin
      FreeAndNil(NoticeBefore);
      NoticeBefore := RoomsSeen.Clone as TJSONArray;
    end;
    NoticePending := True;
    NoticeChannel := RingRoom;
    Inc(NoticeSerial);
  end;
  try
    // From either side: a message of one's own sent from another device too.
    if (Kind = 'dm') and InDm and (SameText(Who, Copy(Room, 2, MaxInt)) or SameText(Who, MyName)) then
    begin
      DmCheckDue := True;
      DmNews;
    end;
    Sync;
    if ThreadPane.Visible and (RingRoom = Room) then
      ThreadPane.Refresh;
  except
    Exit;
  end;
  // A note from the tray only when the window is not where the member looks.
  if not Application.Active or (WindowState = wsMinimized) then
    if Kind = 'dm' then
    begin
      PendingTarget := '@' + Who;
      Notify('Private message', 'From ' + Who + '.');
    end;
end;

{ The typing note shows while the other member types and goes a few
  seconds after the last word; an edit's note is left alone. }
procedure TMainForm.SaidTyping(const Who: string);
begin
  // One's own notice comes back over the live connection too.
  if OpeningBusy or (EditingId > 0) or (Who = '') or SameText(Who, MyName) then
    Exit;
  TypingLabel.Caption := UTF8Copy(Who, 1, 60) + ' is typing...';
  TypingSeen := GetTickCount64;
  TypingTimer.Enabled := True;
end;

procedure TMainForm.TypingTick(Sender: TObject);
begin
  if GetTickCount64 - TypingSeen < 6000 then
    Exit;
  TypingTimer.Enabled := False;
  if EditingId = 0 then
    TypingLabel.Caption := '';
end;

procedure TMainForm.FocusComposer;
begin
  if Composer.CanFocus then
    Composer.SetFocus;
end;

{ The word at the caret, when it starts with @, # or / (a command only at
  the very start), and what could complete it: names seen in the room, the
  rooms, the server's commands.  Eight at most, over the message box. }
procedure TMainForm.UpdateSuggest;
var
  Typed, word, Rest, Offered: string;
  P, I, Shown_: integer;
  Kind: char;
  Names: TStringList;
  Item: TJSONEnum;

  procedure Offer(const S: string);
  begin
    if (Rest = '') or AnsiStartsText(Rest, S) then
      if Names.IndexOf(S) < 0 then
        Names.Add(S);
  end;

begin
  Typed := Composer.Text;
  // The caret counts characters; the text is walked in bytes.
  P := Length(UTF8Copy(Typed, 1, Composer.SelStart));
  I := P;
  while (I > 0) and not (Typed[I] in [' ', #9, #10, #13]) do
    Dec(I);
  word := Copy(Typed, I + 1, P - I);
  if (Length(word) < 1) or not (word[1] in ['@', '#', '/']) or ((word[1] = '/') and (I > 0)) then
  begin
    SuggestTimer.Enabled := False;
    SuggestQuery := '';
    Inc(SuggestGen);
    HideSuggest;
    Exit;
  end;
  Kind := word[1];
  Rest := Copy(word, 2, MaxInt);
  SuggestStart := I + 1;
  Names := TStringList.Create;
  try
    case Kind of
      '@':
      begin
        for Item in HereSeen do
          Offer(TJSONObject(Item.Value).Get('name', ''));
        for Item in Staff do
          Offer(TJSONObject(Item.Value).Get('name', ''));
        for Shown_ := Shown.Count - 1 downto 0 do
          Offer(TJSONObject(Shown[Shown_]).Get('name', ''));
        for Item in DmsSeen do
          Offer(TJSONObject(Item.Value).Get('name', ''));
        // Nobody here by that name: the server knows more members.
        if (Names.Count = 0) and (Length(Rest) >= 2) then
        begin
          if SuggestQuery <> Rest then
          begin
            SuggestQuery := Rest;
            SuggestNames.Clear;
            Inc(SuggestGen);
            SuggestTimer.Enabled := False;
            SuggestTimer.Enabled := True;
          end;
          for Offered in SuggestNames do
            Offer(Offered);
        end;
        // Not oneself.
        I := Names.IndexOf(MyName);
        if I >= 0 then
          Names.Delete(I);
      end;
      '#':
        for Item in RoomsSeen do
          Offer(TJSONObject(Item.Value).Get('slug', ''));
      '/':
      begin
        for I := 0 to Commands.Count - 1 do
          Offer(Commands.Names[I]);
      end;
    end;
    while Names.Count > 8 do
      Names.Delete(Names.Count - 1);
    if Names.Count = 0 then
    begin
      HideSuggest;
      Exit;
    end;
    Suggest.Items.BeginUpdate;
    try
      Suggest.Items.Clear;
      for I := 0 to Names.Count - 1 do
        if Kind = '/' then
          Suggest.Items.Add('/' + Names[I] + '  ' + Commands.Values[Names[I]])
        else
          Suggest.Items.Add(Kind + Names[I]);
    finally
      Suggest.Items.EndUpdate;
    end;
  finally
    Names.Free;
  end;
  Suggest.ItemIndex := 0;
  Suggest.Height := Suggest.Count * Max(Suggest.ItemHeight, 24) + 6;
  Suggest.Width := Min(Scale96ToForm(360), ComposerPanel.Width);
  Suggest.Left := ComposerPanel.Left;
  Suggest.Top := ComposerPanel.Top - Suggest.Height - 2;
  Suggest.Visible := True;
  Suggest.BringToFront;
end;

procedure TMainForm.SuggestTick(Sender: TObject);
begin
  SuggestTimer.Enabled := False;
  ApiGetAsync('/api/users?' + Query(['q', SuggestQuery]), @SuggestDone, SuggestGen, 'suggest');
end;

procedure TMainForm.SuggestDone(Job: TApiJob);
var
  List: TJSONArray;
  Item: TJSONEnum;
begin
  if (Job.Tag <> SuggestGen) or (Job.Error <> '') then
    Exit;
  List := Job.ArrayJSON;
  try
    SuggestNames.Clear;
    for Item in List do
      SuggestNames.Add(TJSONObject(Item.Value).Get('name', ''));
  finally
    List.Free;
  end;
  if Composer.Focused and not OpeningBusy then
    UpdateSuggest;
end;

procedure TMainForm.CommandsDone(Job: TApiJob);
var
  List: TJSONArray;
  Item: TJSONEnum;
  Cmd: string;
begin
  if Job.Error <> '' then
    Exit;
  List := Job.ArrayJSON;
  try
    Commands.Clear;
    for Item in List do
    begin
      Cmd := TJSONObject(Item.Value).Get('name', '');
      if Cmd.StartsWith('/') then
        Delete(Cmd, 1, 1);
      Commands.Values[Cmd] := TJSONObject(Item.Value).Get('usage', '');
    end;
  finally
    List.Free;
  end;
  if Composer.Focused then
    UpdateSuggest;
end;

{ The chosen name, room or command takes the place of the word typed. }
procedure TMainForm.AcceptSuggest;
var
  Chosen, Typed: string;
  P: integer;
begin
  if (Suggest.ItemIndex < 0) or not Suggest.Visible then
    Exit;
  Chosen := Suggest.Items[Suggest.ItemIndex];
  if Pos('  ', Chosen) > 0 then
    Chosen := Copy(Chosen, 1, Pos('  ', Chosen) - 1);
  Typed := Composer.Text;
  P := Length(UTF8Copy(Typed, 1, Composer.SelStart));
  Typed := Copy(Typed, 1, SuggestStart - 1) + Chosen + ' ' + Copy(Typed, P + 1, MaxInt);
  HideSuggest;
  Composer.Text := Typed;
  Composer.SelStart := UTF8Length(Copy(Typed, 1, SuggestStart - 1 + Length(Chosen) + 1));
  FocusComposer;
end;

procedure TMainForm.HideSuggest;
begin
  if Suggest.Visible then
    Suggest.Visible := False;
end;

procedure TMainForm.SuggestClick(Sender: TObject);
begin
  AcceptSuggest;
end;

{ Ctrl+U: the view goes to the New messages line, or to the end when the
  room has none. }
procedure TMainForm.FirstUnreadClick(Sender: TObject);
var
  I: integer;
begin
  for I := 0 to Shown.Count - 1 do
    if (DividerId > 0) and (TJSONObject(Shown[I]).Get('id', 0) = DividerId) then
    begin
      ScrollToEntry(I);
      Exit;
    end;
  Messages.ScrollTo(MaxInt);
end;

procedure TMainForm.ScrollToEntry(I: integer);
var
  B: integer;
begin
  for B := 0 to Messages.BlockCount - 1 do
    if Messages.Block(B).Entry = I then
    begin
      Messages.ScrollTo(Max(0, Messages.Block(B).Bounds.Top - 6));
      Exit;
    end;
end;

{ Ctrl+K: a room or a conversation by name, from a list of them all. }
procedure TMainForm.GoToRoomClick(Sender: TObject);
var
  Names: TStringList;
  Item: TJSONEnum;
  I, J: integer;
  Typed: string;
  Target: TApiTarget;
begin
  Target := ApiTarget;
  Names := TStringList.Create;
  try
    for Item in RoomsSeen do
      Names.Add('#' + TJSONObject(Item.Value).Get('slug', ''));
    for Item in DmsSeen do
      Names.Add('@' + TJSONObject(Item.Value).Get('name', ''));
    Typed := Trim(InputComboEx('Go to channel', 'Channel or conversation (type the first letters):', Names, True));
    if not ApiTargetCurrent(Target) then Exit;
    if Typed = '' then
      Exit;
    if not (Typed.StartsWith('#') or Typed.StartsWith('@')) then
      Typed := '#' + Typed;
    I := Names.IndexOf(Typed);
    if I < 0 then
      for J := Names.Count - 1 downto 0 do
        if AnsiStartsText(Typed, Names[J]) then
        begin
          I := J;
          Break;
        end;
    if I < 0 then
    begin
      NoticeToast.Show('No channel or conversation called ' + Typed + '.');
      Exit;
    end;
    if Names[I].StartsWith('#') then
      OpenRoom(Copy(Names[I], 2, MaxInt))
    else
      OpenRoom(Names[I]);
  finally
    Names.Free;
  end;
end;

{ The unread count in the title and on the tray icon, where a taskbar or
  a tray shows it while the window is elsewhere. }
procedure TMainForm.ShowUnread(Count: integer);
var
  Base: string;
begin
  Base := Caption;
  if Base.StartsWith('(') and (Pos(') ', Base) > 0) then
    Base := Copy(Base, Pos(') ', Base) + 2, MaxInt);
  if Count > 0 then
    Caption := '(' + IntToStr(Count) + ') ' + Base
  else
    Caption := Base;
  Tray.Hint := Caption;
  TrayBadge(Count);
end;

{ The row above the message box: each file by name and size, with a link
  that takes it off again.  The panel grows by the row while there is one. }
procedure TMainForm.ShowAttached;
begin
  Inc(AttachGen);
  AttachRow.Caption := AttachedHtml(Attached);
  if Attached.Count = 0 then
    AttachRow.Height := 0
  else
    AttachRow.Height := 24;
  AttachButton.Caption := AttachCaption(Attached);
  ShowAnswer;
end;

procedure TMainForm.ClearAttached;
begin
  Attached.Clear;
  Inc(AttachGen);
  ShowAttached;
end;

procedure TMainForm.AttachRowLink(Sender: TObject; const LinkName: string);
var
  I: integer;
begin
  if not LinkName.StartsWith('drop:') then
    Exit;
  I := StrToIntDef(Copy(LinkName, 6, MaxInt), -1);
  if (I >= 0) and (I < Attached.Count) then
    Attached.Delete(I);
  ShowAttached;
  FocusComposer;
end;

{ Help > Report a problem: the member's words and what the program knows. }
procedure TMainForm.ReportClick(Sender: TObject);
var
  Page: string;
begin
  if InDm then
    Page := '/dm/' + Copy(Room, 2, MaxInt)
  else
    Page := '/p/' + Room;
  if ReportProblem(Page, 'program: Exedra desktop' + LineEnding + 'widgetset: ' + LCLPlatformDirNames[WidgetSet.LCLPlatform] + LineEnding +
    'system: ' + {$I %FPCTARGETOS%} + ' ' + {$I %FPCTARGETCPU%} + LineEnding + 'server: ' + Server + LineEnding + 'signed in: ' + MyName +
    LineEnding + 'window: ' + IntToStr(Width) + 'x' + IntToStr(Height)) then
    NoticeToast.Show('Report sent.');
end;

procedure TMainForm.ThreadClosed(Sender: TObject);
begin
  ThreadPane.ClearThread;
  ThreadPane.Visible := False;
  Splitter3.Visible := False;
  // In one column the thread stood in for the room.
  RoomPanel.Visible := not ListInFront;
  ShowPeople;
end;

procedure TMainForm.ThreadLink(const Link: string);
begin
  MessagesLinkClick(nil, -1, Link);
end;

procedure TMainForm.ThreadPicture(const URL: string; Destination: TStream; var Handled: boolean);
begin
  MessagesResource(nil, URL, Destination, Handled);
end;

procedure TMainForm.LiveGone;
begin
  if not SignInEnded and not ChatOff and not PollingWorks then ConnectionLost(0);
end;

procedure TMainForm.ApiResult(Job: TApiJob);
begin
  // Provider discovery and requests from a previous account cannot change status.
  if Job.ErrorHandled or not AccountResponse(Job.Path, Job.Auth, Server, Token, Job.Epoch, ApiEpoch) then Exit;
  if (Job.Error <> '') and (ConnectionFailure(Job.Status) in [cfUnreachable, cfServer]) then
    ConnectionLost(Job.Status);
  if (Job.Status = 404) and not ChatOff and not Job.Path.EndsWith('/api/rooms') then
    ApiGetAsync('/api/rooms', @ChatProbeDone, 0, 'chat-probe');
  if (Job.Error = '') and (Pos('/api/sync?', Job.Path) > 0) and not ChatOff then
  begin
    PollingWorks := True;
    NoticeBar.Hide('connection');
    ThreadPane.NoticeBar.Hide('connection');
    OutageSince := 0;
    ConnectionText := '';
    RetryBusy := False;
    if RetryDue = 0 then RetryDue := GetTickCount64 + 60000;
    LiveRetry.Enabled := LiveId = '';
  end;
end;

procedure TMainForm.ApiSignInEnded;
begin
  ConnectionLost(401);
end;

procedure TMainForm.ConnectionLost(Status: integer);
begin
  if SignInEnded then Exit;
  if ChatOff and (Status <> 401) then
  begin
    RetryBusy := False;
    RetryDue := GetTickCount64 + 60000;
    Exit;
  end;
  PollingWorks := False;
  RetryStatus := Status;
  if OutageSince = 0 then OutageSince := GetTickCount64;
  if Status = 401 then
  begin
    SignInEnded := True;
    ThreadPane.AccountReady := False;
    RetryBusy := False;
    RetryDue := 0;
    LiveRetry.Enabled := False;
    PingTimer.Enabled := False;
    StopLive;
  end
  else
  begin
    if RetryBusy or (RetryDue = 0) then
    begin
      RetryBusy := False;
      RetryDue := GetTickCount64 + QWord(RetryDelaySeconds(RetryAttempt, Random(1001))) * 1000;
      Inc(RetryAttempt);
    end;
    LiveRetry.Enabled := True;
  end;
  if ApiRetryDue > RetryDue then RetryDue := ApiRetryDue;
  ShowConnection;
end;

procedure TMainForm.ShowConnection;
var
  Words: string;
begin
  if OutageSince = 0 then Exit;
  if RetryBusy then
    Words := ConnectionWords(Server, RetryStatus, 0)
  else
    Words := ConnectionWords(Server, RetryStatus, RetrySecondsLeft(RetryDue, GetTickCount64));
  if (Words = ConnectionText) and NoticeBar.Has('connection') and (not ThreadPane.Visible or ThreadPane.NoticeBar.Has('connection')) then Exit;
  ConnectionText := Words;
  if SignInEnded then
  begin
    NoticeBar.ShowQuestion(Words, mtError, [mrYes, 'Sign in'], 'connection');
    if ThreadPane.Visible then
      ThreadPane.NoticeBar.ShowQuestion(Words, mtError, [mrYes, 'Sign in'], 'connection');
  end
  else
  begin
    NoticeBar.ShowQuestion(Words, mtWarning, [mrRetry, 'Retry now'], 'connection');
    if ThreadPane.Visible then
      ThreadPane.NoticeBar.ShowQuestion(Words, mtWarning, [mrRetry, 'Retry now'], 'connection');
  end;
end;

procedure TMainForm.LiveRetryTick(Sender: TObject);
begin
  if SignInEnded then Exit;
  if ApiRetryDue > RetryDue then RetryDue := ApiRetryDue;
  if RetrySecondsLeft(RetryDue, GetTickCount64) = 0 then
  begin
    if RetryBusy then
    begin
      StopLive;
      ConnectionLost(RetryStatus);
    end
    else
      RetryConnection;
  end
  else
    ShowConnection;
end;

procedure TMainForm.RetryConnection;
begin
  if ApiRetryDue > GetTickCount64 then Exit;
  if SignInEnded or RetryBusy or ProbePending then Exit;
  RetryBusy := True;
  ProbePending := True;
  // Covers a missing hello as well as a refused or failed handshake.
  RetryDue := GetTickCount64 + 45000;
  ShowConnection;
  if ReauthPending then
    ApiGetAsync('/api/me', @ReauthDone, 0, 'connection-probe')
  else
    ApiGetAsync('/api/me', @RetryDone, 0, 'connection-probe');
end;

procedure TMainForm.RetryDone(Job: TApiJob);
begin
  ProbePending := False;
  if SignInEnded then Exit;
  if Job.Error <> '' then
  begin
    if ConnectionFailure(Job.Status) = cfOther then
    begin
      RetryBusy := False;
      RetryDue := 0;
      ConnectionLost(Job.Status);
    end;
    Exit;
  end;
  RetryBusy := True;
  RetryDue := GetTickCount64 + 45000;
  if MyName = '' then
    MeDone(Job)
  else
    ApiGetAsync('/api/rooms', @ChatProbeDone, 0, 'chat-probe');
end;

procedure TMainForm.ChatProbeDone(Job: TApiJob);
var
  WasOff: boolean;
begin
  RetryBusy := False;
  if Job.Status = 404 then
  begin
    if not ChatOff then
    begin
      NoticeBar.Show('The chat is switched off on this server.', mtInformation, [], 'chat-off');
      if ThreadPane.Visible then ThreadPane.NoticeBar.Show('The chat is switched off on this server.', mtInformation, [], 'chat-off');
    end;
    ChatOff := True;
    StopLive;
    RoomHeader.Caption := 'The chat is switched off on this server.';
    CanTalk := False;
    ActSend.Enabled := False;
    AttachButton.Enabled := False;
    Composer.ReadOnly := True;
    ThreadPane.AccountReady := False;
    NoticeBar.Hide('connection');
    ThreadPane.NoticeBar.Hide('connection');
    OutageSince := 0;
    ConnectionText := '';
    PingTimer.Enabled := False;
    RetryDue := GetTickCount64 + 60000;
    LiveRetry.Enabled := True;
    Exit;
  end;
  if Job.Error <> '' then
  begin
    RetryDue := GetTickCount64 + 60000;
    Exit;
  end;
  WasOff := ChatOff;
  ChatOff := False;
  ThreadPane.AccountReady := True;
  NoticeBar.Hide('chat-off');
  ThreadPane.NoticeBar.Hide('chat-off');
  PingTimer.Enabled := True;
  RetryDue := GetTickCount64 + 60000;
  LiveRetry.Enabled := True;
  if WasOff or (Room = '') then OpenRoom(Room);
  DmCheckDue := True;
  Sync;
  if InDm then DmNews;
  try
    StartLive;
  except
    // HTTP polling remains available without WebSockets.
    StopLive;
  end;
end;

procedure TMainForm.ReauthDone(Job: TApiJob);
var
  Me: TJSONObject;
  Perm: TJSONEnum;
begin
  if Job.Error <> '' then
  begin
    RetryDone(Job);
    Exit;
  end;
  Me := Job.ObjectJSON;
  try
    if (MyName <> '') and SameText(MyName, Me.Get('name', '')) then
    begin
      ReauthPending := False;
      RetrySendEpoch := ApiEpoch;
      ThreadPane.AccountReady := True;
      ShowRoomMenu;
      FreeAndNil(MyCan);
      if Me.Find('can') is TJSONArray then
      begin
        MyCan := TStringList.Create;
        for Perm in Me.Arrays['can'] do MyCan.Add(Perm.Value.AsString);
      end;
      MembersItem.Visible := AdminCan(MyCan, 'view-admin');
      ChannelsItem.Visible := AdminCan(MyCan, 'manage-channels');
      PrivateItem.Visible := AdminCan(MyCan, 'manage-private');
      AdminMenu.Visible := MembersItem.Visible or ChannelsItem.Visible or PrivateItem.Visible;
      if OpeningBusy then OpenRoom(Opening);
      RetryDone(Job);
    end
    else
    begin
      Disconnect;
      Application.QueueAsyncCall(@Start, 0);
    end;
  finally
    Me.Free;
  end;
end;

procedure TMainForm.NoticeAnswer(Sender: TObject; const Key: string; Answer: TModalResult);
var
  OldServer, OldToken: string;
begin
  if Key = 'connection' then
  begin
    if SignInEnded then
    begin
      if Answer = mrYes then
      begin
        OldServer := Server;
        OldToken := Token;
        if SignIn then
        begin
          if Server <> OldServer then
          begin
            Disconnect;
            Application.QueueAsyncCall(@Start, 0);
          end
          else
          begin
            // Keep the current draft, edit, answer and sealed attachments when
            // renewing the same account. A different member starts clean.
            ApiForgetAll;
            Inc(RoomGen);
            Inc(UploadGen);
            Uploading := 0;
            DownloadPending.Clear;
            ThreadPane.ResetRequests;
            Sending := False;
            SyncBusy := False;
            SyncAgain := False;
            DmNewsBusy := False;
            IdleBusy := False;
            RowActionBusy := False;
            Fetching := False;
            if MemberAdmin <> nil then MemberAdmin.Reset;
            if ChannelAdmin <> nil then ChannelAdmin.Reset;
            if Oversight <> nil then Oversight.Reset;
            SignInEnded := False;
            ReauthPending := True;
            ThreadPane.AccountReady := False;
            RetryBusy := True;
            ProbePending := True;
            RetryStatus := 0;
            RetryDue := GetTickCount64 + 45000;
            LiveRetry.Enabled := True;
            ApiGetAsync('/api/me', @ReauthDone);
          end;
        end
        else
        begin
          Server := OldServer;
          Token := OldToken;
          ShowConnection;
        end;
      end;
    end
    else if Answer = mrRetry then RetryConnection;
  end
  else if (Key = 'send') and (Answer = mrRetry) and (RetrySendEpoch = ApiEpoch) and (RetrySendRoom = Room) then
    ActSendExecute(nil);
end;

procedure TMainForm.ShowError(E: Exception; const Key: string);
begin
  if ApiErrorHandled(E) then Exit;
  if (E is EApiFailure) and (ConnectionFailure(EApiFailure(E).Status) in [cfUnreachable, cfServer]) then
    ConnectionLost(EApiFailure(E).Status)
  else
    NoticeBar.Show(E.Message, mtError, [], Key);
end;

procedure TMainForm.ShowJobError(Job: TApiJob; const Key: string);
begin
  if Job.ErrorHandled then Exit;
  if ConnectionFailure(Job.Status) in [cfUnreachable, cfServer] then
    ConnectionLost(Job.Status)
  else
    NoticeBar.Show(Job.Error, mtError, [], Key);
end;

procedure TMainForm.SendFailed(Job: TApiJob);
begin
  if Job.ErrorHandled then Exit;
  ShowJobError(Job, 'send-error');
  if (Room <> SentRoom) or OpeningBusy then Exit;
  RetrySendRoom := SentRoom;
  RetrySendEpoch := ApiEpoch;
  NoticeBar.ShowQuestion('The message was not sent. Your text and files are still in the box.',
    mtError, [mrRetry, 'Send again'], 'send');
end;

procedure TMainForm.LiveReady;
begin
  if SignInEnded then Exit;
  LiveRetry.Enabled := False;
  PingTimer.Enabled := True;
  RetryBusy := False;
  RetryDue := 0;
  RetryAttempt := 0;
  ThreadPane.AccountReady := True;
  NoticeBar.Hide('connection');
  ThreadPane.NoticeBar.Hide('connection');
  ConnectionText := '';
  if (OutageSince <> 0) and (GetTickCount64 - OutageSince > 4000) then
    if ThreadPane.Visible and not RoomPanel.Visible then
      ThreadPane.NoticeToast.Show('Connected again.')
    else
      NoticeToast.Show('Connected again.');
  OutageSince := 0;
  try
    if (Room <> '') and not InDm and not OpeningBusy then
      ReadRoomCard;
    if InDm then
    begin
      DmCheckDue := True;
      DmNews;
    end;
    Sync;
  except
    // The next ping tries again.
  end;
end;

{ The window came forward: what is on show counts as read from now. }
procedure TMainForm.FormActivated(Sender: TObject);
begin
  if (MyName = '') or (Room = '') then
    Exit;
  try
    DmTellRead;
    Sync;
  except
  end;
end;

procedure TMainForm.RoomListClick(Sender: TObject);
var
  Slug, Current: string;
begin
  if (RoomList.ItemIndex < 0) or (RoomList.ItemIndex >= Slugs.Count) then
    Exit;
  Slug := Slugs[RoomList.ItemIndex];
  // Against the room on its way when one is, else the one on show.
  Current := Room;
  if OpeningBusy then
    Current := Opening;
  if (Slug <> '') and (Slug <> Current) then
    OpenRoom(Slug)
  else if Slug <> '' then
    ShowList(False);
  // A heading is not a place to stay on.
  if (Slug = '') and (Slugs.IndexOf(Room) >= 0) then
    RoomList.ItemIndex := Slugs.IndexOf(Room);
end;

function TMainForm.SidebarRoom(const Slug: string): TJSONObject;
var
  Item: TJSONEnum;
begin
  Result := nil;
  for Item in RoomsSeen do
    if TJSONObject(Item.Value).Get('slug', '') = Slug then
      Exit(TJSONObject(Item.Value));
end;

procedure TMainForm.RoomListMenu(Sender: TObject; Index: integer; const MenuPosition: TPoint);
var
  Available: TRowActions;
begin
  if (MyName = '') or (Index < 0) or (Index >= Slugs.Count) or (Slugs[Index] = '') then
    Exit;
  RowTarget := Slugs[Index];
  RowEpoch := ApiEpoch;
  Available := RowActions(SidebarRoom(RowTarget), RowTarget.StartsWith('@'));
  RowLeaveItem.Visible := raLeave in Available;
  RowDeleteChannelItem.Visible := raDeleteChannel in Available;
  RowDeleteDmItem.Visible := raDeleteConversation in Available;
  RowSilenceItem.Visible := raSilence in Available;
  RowMentionsItem.Visible := raMentions in Available;
  RowNotifyAllItem.Visible := raNotifyAll in Available;
  RowLeaveItem.Enabled := not RowActionBusy;
  RowDeleteChannelItem.Enabled := not RowActionBusy;
  RowDeleteDmItem.Enabled := not RowActionBusy;
  RowSilenceItem.Enabled := not RowActionBusy;
  RowMentionsItem.Enabled := not RowActionBusy;
  RowNotifyAllItem.Enabled := not RowActionBusy;
  if Available <> [] then
    RowMenu.PopUp(MenuPosition.X, MenuPosition.Y);
  RoomList.ItemIndex := Slugs.IndexOf(Room);
end;

procedure TMainForm.RowActionClick(Sender: TObject);
begin
  if RowEpoch = ApiEpoch then
    ActOnRow(RowTarget, TRowAction(TMenuItem(Sender).Tag));
end;

procedure TMainForm.ActOnRow(Target: string; RowAction: TRowAction);
var
  Info: TJSONObject;
  Words, Title, Path: string;
  Epoch: integer;
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if RowActionBusy or (Target = '') or (MyName = '') then
    Exit;
  Info := SidebarRoom(Target);
  Title := Target;
  if Info <> nil then
    Title := Info.Get('title', Target);
  Words := '';
  case RowAction of
    raSilence, raMentions, raNotifyAll:
    begin
      if not (RowAction in RowActions(Info, Target.StartsWith('@'))) then
        Exit;
      Path := '/api/follow/notify';
    end;
    raLeave:
    begin
      // The main menu can also leave a channel opened outside the sidebar.
      if (Info = nil) and (Room = Target) then
        Info := Card;
      if (Info = nil) or not Info.Get('following', True) then
        Exit;
      if Info.Get('private', False) then
        Words := 'Leave #' + Title + '? You will need an invitation to return.';
      Path := '/api/follow';
    end;
    raDeleteChannel:
    begin
      if not (raDeleteChannel in RowActions(Info, False)) then
        Exit;
      Words := 'Delete #' + Title + ' for good, including all its messages and files? This cannot be undone.';
      Path := '/api/room/delete';
    end;
    raDeleteConversation:
    begin
      if not Target.StartsWith('@') then
        Exit;
      Title := Copy(Target, 2, MaxInt);
      Words := 'Delete your copy of the conversation with ' + Title + '? ' + Title + ' keeps theirs.';
      Path := '/api/dm/delete';
    end;
  end;
  Epoch := ApiEpoch;
  if (Words <> '') and (MessageDlg(Words, mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes) then
    Exit;
  if Epoch <> ApiEpoch then
    Exit;
  RowActionBusy := True;
  try
    case RowAction of
      raSilence, raMentions, raNotifyAll:
        ApiPostAsync(Path, ['room', Target, 'mode', NotifyActionMode(RowAction)], @RowActionDone, Ord(RowAction), '', Target);
      raLeave: ApiPostAsync(Path, ['room', Target, 'on', '0'], @RowActionDone, Ord(RowAction), '', Target);
      raDeleteChannel: ApiPostAsync(Path, ['slug', Target], @RowActionDone, Ord(RowAction), '', Target);
      raDeleteConversation: ApiPostAsync(Path, ['with', Title], @RowActionDone, Ord(RowAction), '', Target);
    end;
  except
    RowActionBusy := False;
    raise;
  end;
end;

procedure TMainForm.RowActionDone(Job: TApiJob);
var
  Info: TJSONObject;
begin
  RowActionBusy := False;
  if Job.Error = '' then
  begin
    if NotifyActionMode(TRowAction(Job.Tag)) <> '' then
    begin
      Info := SidebarRoom(Job.Context);
      if Info <> nil then
        Info.Strings['notify'] := NotifyActionMode(TRowAction(Job.Tag));
      if (Job.Tag = Ord(raSilence)) and (PendingTarget = Job.Context) then
        PendingTarget := '';
      ShowRooms;
    end
    else if (Room = Job.Context) or (OpeningBusy and (Opening = Job.Context)) then
    begin
      ClearCurrent;
      OpenRoom('');
    end;
  end;
  // A refusal can mean that membership or ownership changed elsewhere.
  ShowRoomMenu;
  RefreshRooms;
  if Job.Error <> '' then
    ShowJobError(Job, 'rowactiondone')
  else if (Job.Tag = Ord(raDeleteChannel)) and (Trim(Job.Answer) <> '') then
    NoticeToast.Show(Trim(Job.Answer));
end;

procedure TMainForm.RefreshRooms;
begin
  if SignInEnded or ChatOff then Exit;
  ApiGetAsync('/api/sync?rooms=1', @RoomsDone, NoticeSerial, 'sidebar');
end;

procedure TMainForm.RoomsDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if Job.Error <> '' then
    Exit;
  Answer := Job.ObjectJSON;
  try
    if Answer.Find('rooms') is TJSONArray then
    begin
      NotifyRooms(Answer.Arrays['rooms'], Job.Tag);
      RoomsSeen.Free;
      RoomsSeen := Answer.Arrays['rooms'].Clone as TJSONArray;
    end;
    if Answer.Find('dms') is TJSONArray then
    begin
      DmsSeen.Free;
      DmsSeen := Answer.Arrays['dms'].Clone as TJSONArray;
    end;
    ShowRooms;
  finally
    Answer.Free;
  end;
end;

procedure TMainForm.ActPeopleExecute(Sender: TObject);
begin
  ShowPeople;
end;

procedure TMainForm.MessagesLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
var
  Emoji: string;
  I, Id: integer;
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(LinkName) <> LinkName then
  begin
    MessagesLinkClick(Sender, LineIndex, SiteLocal(LinkName));
    Exit;
  end;
  if LinkName.StartsWith('preview:') then
  begin
    Id := StrToIntDef(Copy(LinkName, 9, MaxInt), 0);
    for I := 0 to Shown.Count - 1 do
      if TJSONObject(Shown[I]).Get('id', 0) = Id then
      begin
        Previews.Toggle(TJSONObject(Shown[I]));
        PutEntry(I);
        Break;
      end;
  end
  else if LinkName.StartsWith('react:') then
  begin
    // adds one's own reaction, or takes it back
    Emoji := ReactionOfLink(Shown, LinkName, Id);
    ReactToMessage(Id, Emoji);
  end
  else if LinkName.StartsWith('dmquote:') then
  begin
    Id := StrToIntDef(Copy(LinkName, 9, MaxInt), 0);
    for I := 0 to Shown.Count - 1 do
      if TJSONObject(Shown[I]).Get('id', 0) = Id then
      begin
        JumpId := Id;
        JumpStep;
        Exit;
      end;
    NoticeToast.Show('That message is further back.');
  end
  else if LinkName = 'beam:' then
    OpenURL(Server + '/dm/' + Copy(Room, 2, MaxInt))   // a beam is the website's job
  else if LinkName.StartsWith('sealed:') then
    SaveSealed(Copy(LinkName, 8, MaxInt))
  else if LinkName.StartsWith('thread:') then
  begin
    OpenThreadOn(StrToIntDef(Copy(LinkName, 8, MaxInt), 0));
  end
  else if LinkName.StartsWith('/p/') then
    OpenRoom(Copy(LinkName, 4, MaxInt))
  else if LinkName.StartsWith('/u/') then
    ShowProfile(DecodeURLElement(Copy(LinkName, 4, MaxInt)), MyName)
  else if LinkName.StartsWith('/') then
    OpenURL(Server + LinkName)
  else if WebAddress(LinkName) then
    OpenURL(LinkName);
end;

procedure TMainForm.MessagesKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  I, J, OldFocus: integer;
  Preview: TJSONObject;
begin
  if (Shift = [ssAlt]) and ((Key = VK_DOWN) or (Key = VK_UP)) then
  begin
    OldFocus := Previews.FocusId;
    I := Previews.Step(Shown, Key = VK_UP);
    if I >= 0 then
    begin
      for J := 0 to Shown.Count - 1 do
        if (J <> I) and (TJSONObject(Shown[J]).Get('id', 0) = OldFocus) then
          PutEntry(J);
      PutEntry(I);
      ScrollToEntry(I);
    end;
    Key := 0;
  end
  else if (Shift = []) and ((Key = VK_RETURN) or (Key = VK_SPACE)) and (Previews.FocusId > 0) then
  begin
    MessagesLinkClick(Sender, -1, 'preview:' + IntToStr(Previews.FocusId));
    Key := 0;
  end
  else if (Shift = [ssCtrl]) and (Key = VK_RETURN) then
  begin
    for I := 0 to Shown.Count - 1 do
      if TJSONObject(Shown[I]).Get('id', 0) = Previews.FocusId then
      begin
        Preview := PreviewOf(TJSONObject(Shown[I]));
        if Preview <> nil then
          OpenURL(Preview.Get('url', ''));
        Break;
      end;
    Key := 0;
  end;
end;

{ A picture in a message: from what came before, or fetched now and shown
  when it arrives. }
procedure TMainForm.MessagesResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
var
  Path: string;
  Meta: TJSONObject;
  Entry: TPictureEntry;
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(URL) <> URL then
  begin
    MessagesResource(Sender, SiteLocal(URL), Destination, Handled);
    Exit;
  end;
  Handled := True;
  if URL.StartsWith('preview-image:') then
  begin
    Path := Copy(URL, 15, MaxInt);
    if not (WebAddress(Path) or Path.StartsWith('/f/')) then Exit;
  end
  else if not (URL.StartsWith('/f/') or URL.StartsWith('sealed:')) then Exit;
  Entry := Pictures.Read(URL);
  if Entry <> nil then
  begin
    Entry.Position := 0;
    Destination.CopyFrom(Entry, Entry.Size);
    Exit;
  end;
  if URL.StartsWith('sealed:') then
  begin
    Meta := SealedMeta(Copy(URL, 8, MaxInt));
    if (Meta = nil) or Meta.Get('once', False) then Exit;
  end;
  if not Pictures.BeginFetch(URL) then Exit;
  if URL.StartsWith('preview-image:') then
  begin
    if not Fetch(Path, @FetchedPreview, True, RoomGen) then Pictures.Failed(URL);
  end
  else if URL.StartsWith('sealed:') then
  begin
    if not Fetch('/f/' + Copy(URL, 8, MaxInt) + '/sealed', @FetchedSealed, False, RoomGen) then Pictures.Failed(URL);
  end
  else if not Fetch(URL, @Fetched, False, RoomGen) then Pictures.Failed(URL);
end;

procedure TMainForm.FetchedPreview(const Path: string; Bytes: TBytes; FetchTag: integer);
begin
  Fetched('preview-image:' + Path, Bytes, FetchTag);
end;

procedure TMainForm.FetchedSealed(const Path: string; Bytes: TBytes; FetchTag: integer);
var
  FileToken, PathKey: string;
  Meta: TJSONObject;
  Plain: TBytes;
begin
  FileToken := Copy(Path, 4, Length(Path) - 3 - Length('/sealed'));
  PathKey := 'sealed:' + FileToken;
  if FetchTag <> RoomGen then
  begin
    Pictures.Failed(PathKey);
    Exit;
  end;
  Meta := SealedMeta(FileToken);
  if (Length(Bytes) = 0) or (Meta = nil) or (DmKey = nil) then
  begin
    Pictures.Failed(PathKey);
    Exit;
  end;
  try
    try
      Plain := OpenBytes(DmKey, Bytes, Meta.Get('iv', ''));
      Fetched(PathKey, Plain, FetchTag);
    except
      Pictures.Failed(PathKey);
    end;
  finally
    WipeBytes(Plain);
  end;
end;

procedure TMainForm.PictureDropped(const Path: string);
begin
  Messages.ResourceChanged(Path);
  ThreadPane.PictureArrived(Path);
  FindPictureArrived(Path);
end;

procedure TMainForm.Fetched(const Path: string; Bytes: TBytes; FetchTag: integer);
begin
  if Pictures.Complete(Path, Bytes) then PictureDropped(Path);
end;

procedure TMainForm.ComposerKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  I: integer;
begin
  if Key = VK_ESCAPE then
  begin
    SuggestTimer.Enabled := False;
    SuggestQuery := '';
    Inc(SuggestGen);
  end;
  // With suggestions showing: Up and Down pick, Tab and Enter take, Esc closes.
  if Suggest.Visible then
  begin
    if Key = VK_DOWN then
      Suggest.ItemIndex := Min(Suggest.ItemIndex + 1, Suggest.Count - 1)
    else if Key = VK_UP then
      Suggest.ItemIndex := Max(Suggest.ItemIndex - 1, 0)
    else if (Key = VK_TAB) or (Key = 13) then
      AcceptSuggest
    else if Key = VK_ESCAPE then
      HideSuggest
    else
      Exit;
    Key := 0;
    Exit;
  end;
  // Enter sends; Shift+Enter starts a new line; Up in an empty box edits
  // the last message of one's own; Esc stops editing.
  if (Key = VK_UP) and (Composer.Text = '') then
  begin
    I := Shown.Count - 1;
    while (I >= 0) and (TJSONObject(Shown[I]).Get('name', '') <> MyName) do
      Dec(I);
    if I >= 0 then
    begin
      Key := 0;
      StartEdit(I);
    end;
  end
  else if (Key = VK_ESCAPE) and (EditingId > 0) then
  begin
    StopEdit;
    Key := 0;
  end
  else if (Key = VK_ESCAPE) and (DmReply <> nil) then
  begin
    ClearAnswer;
    Key := 0;
  end
  else if (Key = 13) and not (ssShift in Shift) and not InCodeFence(Composer.Text, Composer.SelStart) then
  begin
    Key := 0;
    ActSend.Execute;
  end
  else if Key = 13 then
  begin
    Key := 0;
    Composer.SelText := LineEnding;
  end;
end;

procedure TMainForm.ActSendExecute(Sender: TObject);
var
  Typed, Answered: string;
begin
  if SignInEnded or ReauthPending or ChatOff or Sending or (Uploading > 0) or OpeningBusy or not CanTalk then
    Exit;
  if (EditingId = 0) and (Trim(Composer.Text) = '') and (Attached.Count = 0) then
    Exit;
  if not InDm and (EditingId > 0) and (Trim(Composer.Text) = '') then
    Exit;
  try
    Typed := Composer.Text;
    if InDm and (EditingId > 0) then
      SendDmEdit(Typed)
    else if (EditingId = 0) and (Typed.StartsWith('/msg ') or Typed.StartsWith('/query ')) then
      StartConversation(Typed)
    else if InDm then
      SendDm(Typed)
    else if EditingId > 0 then
    begin
      Sending := True;
      SentText := Typed;
      SentRoom := Room;
      ApiPostAsync('/api/edit', ['id', IntToStr(EditingId), 'body', Typed], @EditDone, EditingId);
    end
    else
    begin
      // The box is cleared once the server has it, and only if it still
      // holds what was sent: typing goes on meanwhile.
      Sending := True;
      SentText := Typed;
      SentRoom := Room;
      SentAttach := AttachGen;
      SentReplySerial := ReplySerial;
      Answered := '';
      if DmReply <> nil then
        Answered := IntToStr(DmReply.Get('id', 0));
      ApiPostAsync('/api/post', ['room', Room, 'parent', '', 'body', Typed, 'files', AttachedTokens(Attached), 're', Answered], @PostDone, RoomGen);
    end;
  except
    on E: Exception do
    begin
      Sending := False;
      ShowError(E, 'actsendexecute');
      if (E is EApiFailure) then
      begin
        RetrySendRoom := Room;
        RetrySendEpoch := ApiEpoch;
        NoticeBar.ShowQuestion('The message was not sent. Your text and files are still in the box.',
          mtError, [mrRetry, 'Send again'], 'send');
      end;
    end;
  end;
end;

procedure TMainForm.PostDone(Job: TApiJob);
var
  Answer: TJSONObject;
  Go: string;
begin
  Sending := False;
  if Job.Error <> '' then
  begin
    SendFailed(Job);
    Exit;
  end;
  if (SentRoom = Room) and not OpeningBusy and (SentReplySerial = ReplySerial) then
    ClearAnswer;
  SentAccepted;
  Answer := Job.ObjectJSON;
  try
    // What a command answers is for this member only (/help, /whois...).
    if Answer.Get('info', '') <> '' then
      NoticeToast.Show(Answer.Get('info', ''));
    Go := Answer.Get('go', '');
    if (Job.Tag = RoomGen) and Go.StartsWith('/p/') then
      OpenRoom(Copy(Go, 4, MaxInt))
    else if (Job.Tag = RoomGen) and (Go = '/') then
      OpenRoom('')   // /part: the room is no longer this member's
    else if Job.Tag = RoomGen then
      Sync;
  finally
    Answer.Free;
  end;
end;

procedure TMainForm.EditDone(Job: TApiJob);
begin
  Sending := False;
  if Job.Error <> '' then
  begin
    SendFailed(Job);
    Exit;
  end;
  // Still editing that one: the draft put aside comes back.
  if (Room = SentRoom) and (EditingId = Job.Tag) then
    StopEdit;
  Sync;
end;

{ The private key, asked for once after the program starts: the password
  opens the copy the server keeps wrapped. }
function TMainForm.HaveMyKey(Job: TApiJob): boolean;
var
  Password: string;
begin
  Result := True;
  if (MyKey <> nil) or (KeyPromptGeneration = RoomGen) then Exit;
  KeyPromptGeneration := RoomGen;
  Password := '';
  try
    if not InputQuery('Locked conversation', 'Your password opens it:', True, Password) then Exit;
    if (Job.Epoch <> ApiEpoch) or (Job.Tag <> RoomGen) then Exit(False);
    WipeText(KeyPassword);
    WipeBytes(KeyWrap);
    KeyPassword := Password;
    KeyGeneration := RoomGen;
    KeyAnswer := Job.Answer;
    ApiGetAsync('/api/auth-name?' + Query(['name', MyName]), @KeySaltDone, RoomGen);
    Result := False;
  finally
    WipeText(Password);
  end;
end;

procedure TMainForm.KeySaltDone(Job: TApiJob);
var
  Answer: TJSONObject;
  Auth: string;
begin
  if (Job.Tag <> RoomGen) or (Job.Tag <> KeyGeneration) then Exit;
  try
    try
      Answer := Job.ObjectJSON;
      try
        PasswordKeys(Answer.Get('name', MyName), KeyPassword, Auth, KeyWrap);
      finally
        Answer.Free;
      end;
      ApiGetAsync('/api/me', @MyKeyDone, RoomGen);
    except
      on E: Exception do
      begin
        if not ApiErrorHandled(E) then ShowError(E, 'havemykey');
        Job.Error := '';
        Job.Answer := '{}';
        MyKeyDone(Job);
      end;
    end;
  finally
    WipeText(KeyPassword);
    WipeText(Auth);
  end;
end;

procedure TMainForm.MyKeyDone(Job: TApiJob);
var
  Answer: TJSONObject;
  Resume: TApiJob;
begin
  if (Job.Tag <> RoomGen) or (Job.Tag <> KeyGeneration) then Exit;
  try
    try
      Answer := Job.ObjectJSON;
      try
        if (Answer.Get('wrapped', '') <> '') and (KeyWrap <> nil) then
          MyKey := Unwrap(Answer.Get('wrapped', ''), KeyWrap);
      finally
        Answer.Free;
      end;
    except
      on E: Exception do ShowError(E, 'havemykey');
    end;
  finally
    WipeBytes(KeyWrap);
    WipeText(KeyPassword);
  end;
  Resume := TApiJob.Create;
  try
    Resume.Answer := KeyAnswer;
    Resume.Tag := Job.Tag;
    Resume.Epoch := Job.Epoch;
    KeyAnswer := '';
    DmDone(Resume);
  finally
    Resume.Free;
  end;
end;

{ A private message opened when it is locked and the key is here, then made
  to look like a room message. }
function TMainForm.Readable(Item: TJSONObject): TJSONObject;
var
  Opened: TJSONObject;
  FromName, ToName: string;
begin
  if (Item.Get('iv', '') = '') or (DmKey = nil) then
    Exit(DmAsMessage(Item));
  FromName := Item.Get('from_key_name', Item.Get('from', ''));
  ToName := MyKeyName;
  if SameText(Item.Get('from', ''), MyName) then
    ToName := DmKeyName;
  Opened := Item.Clone as TJSONObject;
  try
    try
      Opened.Strings['data'] := Open(DmKey, FromName, ToName, Item.Get('iv', ''), Item.Get('data', ''));
      Opened.Strings['iv'] := '';
    except
      // Not openable with this key: shown as locked.
    end;
    Result := DmAsMessage(Opened, True);
  finally
    Opened.Free;
  end;
end;

{ A locked file: fetched, opened here and saved where the member says. }
{ The file entry of a sealed attachment on show, by its token: it carries
  the iv the bytes were sealed with. }
function TMainForm.SealedMeta(const Token: string): TJSONObject;
var
  Item, F: TJSONEnum;
begin
  Result := nil;
  for Item in Shown do
    for F in ArrayOf(TJSONObject(Item.Value), 'files') do
      if TJSONObject(F.Value).Get('token', '') = Token then
        Result := TJSONObject(F.Value);
end;

function TMainForm.SealedMessageId(const FileToken: string): integer;
var
  Item, FileInfo: TJSONEnum;
begin
  Result := 0;
  for Item in Shown do
    for FileInfo in ArrayOf(TJSONObject(Item.Value), 'files') do
      if TJSONObject(FileInfo.Value).Get('token', '') = FileToken then
        Exit(TJSONObject(Item.Value).Get('id', 0));
end;

procedure TMainForm.SaveDownload(const FileToken, FileName, IV: string; const Key: TBytes);
var
  I, RawIndex: integer;
  Data, Raw: TBytesStream;
  Picture: TPictureEntry;
  Plain: TBytes;
begin
  I := Downloads.IndexOf(FileToken);
  if I < 0 then
  begin
    Picture := Pictures.Read('sealed:' + FileToken);
    Data := TBytesStream.Create;
    try
      if Picture <> nil then
      begin
        Picture.Position := 0;
        Data.CopyFrom(Picture, Picture.Size);
      end
      else
      begin
        RawIndex := Downloads.IndexOf('raw:' + FileToken);
        if RawIndex < 0 then Exit;
        Raw := TBytesStream(Downloads.Objects[RawIndex]);
        Plain := OpenBytes(Key, Copy(Raw.Bytes, 0, Raw.Size), IV);
        if Length(Plain) > 0 then Data.WriteBuffer(Plain[0], Length(Plain));
      end;
      I := Downloads.AddObject(FileToken, Data);
      Data := nil;
    finally
      Data.Free;
      WipeBytes(Plain);
    end;
  end;
  TBytesStream(Downloads.Objects[I]).SaveToFile(FileName);
end;

procedure TMainForm.SaveSealed(const FileToken: string);
var
  Meta: TJSONObject;
  Context: TSealedDownload;
  Target: TApiTarget;
  Generation: integer;
begin
  if DownloadPending.IndexOf(FileToken) >= 0 then Exit;
  Meta := SealedMeta(FileToken);
  if (Meta = nil) or (DmKey = nil) then Exit;
  Context := TSealedDownload.Create;
  try
    try
      Context.IV := Meta.Get('iv', '');
      Context.MessageId := SealedMessageId(FileToken);
      Context.Key := Copy(DmKey);
      Context.FileToken := FileToken;
      Target := ApiTarget;
      Generation := RoomGen;
      SaveDialog1.FileName := Meta.Get('name', 'file');
      if not SaveDialog1.Execute then Exit;
      if not ApiTargetCurrent(Target) or (Generation <> RoomGen) or (SealedMeta(FileToken) = nil) or (Context.MessageId <> SealedMessageId(FileToken)) then Exit;
      Context.FileName := SaveDialog1.FileName;
      if (Downloads.IndexOf(FileToken) >= 0) or (Downloads.IndexOf('raw:' + FileToken) >= 0) or (Pictures.Read('sealed:' + FileToken) <> nil) then
        SaveDownload(FileToken, Context.FileName, Context.IV, Context.Key)
      else
      begin
        ApiBytesAsync('/f/' + FileToken + '/sealed', @DownloadDone, RoomGen, '', Context);
        Context := nil;
        DownloadPending.Add(FileToken);
      end;
    except
      on E: Exception do ShowError(E, 'savesealed');
    end;
  finally
    Context.Free;
  end;
end;

procedure TMainForm.DownloadDone(Job: TApiJob);
var
  Context: TSealedDownload;
  I: integer;
  Raw: TBytesStream;
begin
  Context := TSealedDownload(Job.Payload);
  I := DownloadPending.IndexOf(Context.FileToken);
  if I >= 0 then DownloadPending.Delete(I);
  if (Job.Tag <> RoomGen) or (Context.MessageId <> SealedMessageId(Context.FileToken)) then Exit;
  if Job.Error <> '' then
  begin
    ShowJobError(Job, 'savesealed');
    Exit;
  end;
  // Retain ciphertext before decrypting or writing, including one-download files.
  I := Downloads.IndexOf('raw:' + Context.FileToken);
  if I < 0 then
  begin
    Raw := Job.Data;
    Job.Data := nil;
    Downloads.AddObject('raw:' + Context.FileToken, Raw);
  end;
  try
    SaveDownload(Context.FileToken, Context.FileName, Context.IV, Context.Key);
  except
    on E: Exception do ShowError(E, 'savesealed');
  end;
end;

function TMainForm.InDm: boolean;
begin
  Result := Room.StartsWith('@');
end;

{ A private conversation: its newest messages, sealed ones opened with the
  pair's key when this member's own key is at hand.  Nothing about the
  conversation on show changes until the new one has been read. }

{ A private conversation opens in two reads: whether it is locked and
  the other member's key, then the messages.  Nothing about the one on
  show changes until the second is in. }
procedure TMainForm.DmKeyDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if Job.Tag <> RoomGen then
    Exit;
  if Job.Error <> '' then
  begin
    RoomFailed(Job.Error, Job.ErrorHandled);
    Exit;
  end;
  Answer := Job.ObjectJSON;
  try
    OpenLocked := Answer.Get('locked', False);
    OpenPub := Answer.Get('pub', '');
    OpenKeyName := Answer.Get('key_name', Copy(Opening, 2, MaxInt));
  finally
    Answer.Free;
  end;
  ApiGetAsync(DmAsk(Copy(Opening, 2, MaxInt), daOpen, 0), @DmDone, RoomGen);
end;

procedure TMainForm.DmDone(Job: TApiJob);
var
  Answer: TJSONData;
  Item: TJSONEnum;
  Sealed, Locked: boolean;
  Who, PublicKey: string;
  ConversationKey: TBytes;
begin
  if (Job.Epoch <> ApiEpoch) or (Job.Tag <> RoomGen) then
    Exit;
  if Job.Error <> '' then
  begin
    RoomFailed(Job.Error, Job.ErrorHandled);
    Exit;
  end;
  Who := Copy(Opening, 2, MaxInt);
  Locked := OpenLocked;
  PublicKey := OpenPub;
  ConversationKey := nil;
  Answer := Job.JSON;
  try
    // Sealed messages stay sealed after an unlock, so the key is wanted for them too.
    Sealed := Locked;
    for Item in TJSONArray(Answer) do
      if TJSONObject(Item.Value).Get('iv', '') <> '' then
        Sealed := True;
    if Sealed and (PublicKey <> '') then
    begin
      if not HaveMyKey(Job) then Exit;
      if (Job.Epoch <> ApiEpoch) or (Job.Tag <> RoomGen) then
        Exit;
      try
        if MyKey <> nil then ConversationKey := PairKey(MyKey, PublicKey);
      except
        on E: Exception do
        begin
          RoomFailed(E.Message);
          Exit;
        end;
      end;
    end;
    if (Job.Epoch <> ApiEpoch) or (Job.Tag <> RoomGen) then
      Exit;
    OpeningBusy := False;
    Room := Opening;
    DmLocked := Locked;
    WipeBytes(DmKey);
    DmKey := ConversationKey;
    ConversationKey := nil;
    DmKeyName := OpenKeyName;
    Shown.Clear;
    Previews.Clear;
    DividerId := 0;
    LastReadId := 0;
    for Item in TJSONArray(Answer) do
      Shown.Add(Readable(TJSONObject(Item.Value)));
    MoreBefore := TJSONArray(Answer).Count >= 100;
  finally
    Answer.Free;
    WipeBytes(ConversationKey);
  end;
  Staff.Clear;
  HereSeen.Clear;
  if DmLocked and (DmKey <> nil) then
    ShowHeader(IconFor(DmAvatar(Who), Who, True), Who, 'Locked: only the two of you can read it.')
  else if DmLocked then
    ShowHeader(IconFor(DmAvatar(Who), Who, True), Who, 'Locked: open it again and give your password.')
  else
    ShowHeader(IconFor(DmAvatar(Who), Who, True), Who, 'A private conversation.');
  Caption := Who + ' - Exedra';
  Render;
  ShowRoomMenu;
  Sync;
  ShowList(False);
  TakeDraft;
  AfterOpened;
end;

{ Whether the member can be looking at the window. }
function TMainForm.Looking: boolean;
begin
  Result := Application.Active and (WindowState <> wsMinimized);
end;

{ The path for a read of a private conversation.  Away from the window the
  messages stay unread on the server, and the reading is told on return. }
function TMainForm.DmAsk(const Who: string; Ask: TDmAsk; Id: integer): string;
begin
  if not Looking and (Ask <> daOne) then
    DmReadDue := True;
  Result := DmPath(Who, Ask, Id, Looking);
end;

{ Back at the window: the conversation on show counts as read from now. }
procedure TMainForm.DmTellRead;
begin
  if not DmReadDue or not InDm or OpeningBusy or DmNewsBusy or not Looking then
    Exit;
  if SignInEnded or ChatOff then Exit;
  DmReadDue := False;
  DmNewsBusy := True;
  ApiGetAsync(DmPath(Copy(Room, 2, MaxInt), daRead, LastId, True), @DmNewsDone, RoomGen);
end;

{ The server learns whether the window is on screen or minimized. }
procedure TMainForm.TellShown;
begin
  LiveShown(WindowState <> wsMinimized);
end;

procedure TMainForm.WindowStateChanged(Sender: TObject);
begin
  TellShown;
  if WindowState <> wsMinimized then
    FormActivated(Sender);
end;

{ "Seen" under the newest of my messages the other has read: the list of
  conversations says how far (seen), when the site tells it.  The mark
  moves as they read. }
procedure TMainForm.ShowSeen;
var
  Item: TJSONEnum;
  I, UpTo, Was, Mark: integer;
begin
  if not InDm then
    Exit;
  UpTo := 0;
  for Item in DmsSeen do
    if SameText(TJSONObject(Item.Value).Get('name', ''), Copy(Room, 2, MaxInt)) then
      UpTo := TJSONObject(Item.Value).Get('seen', 0);
  Was := -1;
  Mark := -1;
  for I := 0 to Shown.Count - 1 do
  begin
    if TJSONObject(Shown[I]).Get('id', 0) = SeenId then
      Was := I;
    if SameText(TJSONObject(Shown[I]).Get('name', ''), MyName) and (TJSONObject(Shown[I]).Get('id', 0) <= UpTo) then
      Mark := I;
  end;
  if Was = Mark then
    Exit;
  SeenId := 0;
  if Mark >= 0 then
    SeenId := TJSONObject(Shown[Mark]).Get('id', 0);
  if Was >= 0 then
    PutEntry(Was);
  if Mark >= 0 then
    PutEntry(Mark);
end;

procedure TMainForm.DmNews;
begin
  LoadDmNews;
end;

procedure TMainForm.LoadDmNews;
begin
  if SignInEnded or ChatOff then Exit;
  if DmNewsBusy or not InDm or OpeningBusy then
    Exit;
  DmNewsBusy := True;
  // Locked or unlocked from the other side meanwhile: read it afresh.
  ApiGetAsync('/api/key?' + Query(['name', Copy(Room, 2, MaxInt)]), @DmLockDone, RoomGen);
end;

procedure TMainForm.DmLockDone(Job: TApiJob);
var
  Answer: TJSONObject;
  Locked: boolean;
begin
  if Job.Tag <> RoomGen then
    Exit;
  if Job.Error <> '' then
  begin
    DmNewsBusy := False;
    Exit;
  end;
  Answer := Job.ObjectJSON;
  try
    Locked := Answer.Get('locked', False);
  finally
    Answer.Free;
  end;
  if Locked <> DmLocked then
  begin
    DmNewsBusy := False;
    OpenRoom(Room);
    Exit;
  end;
  if DmCheckDue and (Shown.Count > 0) then
  begin
    DmCheckDue := False;
    DmReload.Clear;
    DmReloadFirst := Shown.Objects[0].Get('id', 0);
    DmReloadLast := LastId;
    ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daBefore, DmReloadLast + 1), @DmCheckDone, RoomGen);
  end
  else
    ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daAfter, LastId), @DmNewsDone, RoomGen);
end;

{ Refresh every shown message after missing live updates. }
procedure TMainForm.DmCheckDone(Job: TApiJob);
var
  List: TJSONArray;
  I, First, OldY: integer;
begin
  if Job.Tag <> RoomGen then
    Exit;
  if Job.Error <> '' then
  begin
    DmNewsBusy := False;
    Exit;
  end;
  List := Job.ArrayJSON;
  try
    First := 0;
    if List.Count > 0 then First := List.Objects[0].Get('id', 0);
    for I := List.Count - 1 downto 0 do
      if List.Objects[I].Get('id', 0) >= DmReloadFirst then
        DmReload.Insert(0, Readable(List.Objects[I]));
    if (List.Count >= 100) and (First > DmReloadFirst) then
    begin
      ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daBefore, First), @DmCheckDone, RoomGen);
      Exit;
    end;
  finally
    List.Free;
  end;
  for I := Shown.Count - 1 downto 0 do
    if (Shown.Objects[I].Get('id', 0) >= DmReloadFirst) and (Shown.Objects[I].Get('id', 0) <= DmReloadLast) then Shown.Delete(I);
  First := 0;
  while (First < Shown.Count) and (Shown.Objects[First].Get('id', 0) < DmReloadFirst) do Inc(First);
  for I := 0 to DmReload.Count - 1 do
    Shown.Insert(First + I, DmReload.Items[I].Clone);
  DmReload.Clear;
  OldY := Messages.ScrollY;
  Render;
  Messages.ScrollTo(OldY);
  ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daAfter, LastId), @DmNewsDone, RoomGen);
end;

procedure TMainForm.DmNewsDone(Job: TApiJob);
var
  Answer: TJSONData;
  Item: TJSONEnum;
  First: integer;
  ToldRead: boolean;
begin
  if Job.Tag <> RoomGen then
    Exit;
  DmNewsBusy := False;
  ToldRead := Pos('&read=', Job.Path) > 0;
  if Job.Error <> '' then
  begin
    // Not told after all: once more with the next news.
    if ToldRead then
      DmReadDue := True;
    Exit;
  end;
  Answer := Job.JSON;
  try
    First := Shown.Count;
    for Item in TJSONArray(Answer) do
      Shown.Add(Readable(TJSONObject(Item.Value)));
  finally
    Answer.Free;
  end;
  if Shown.Count > First then
    ShowNew(First);
  ShowSeen;
  // Read now: the list's unread count follows the server's.
  if ToldRead then
    Sync
  else
    DmTellRead;
end;

procedure TMainForm.SendDm(const Words: string);
var
  Payload: TJSONObject;
  Iv, Sealed: string;
  I: integer;
begin
  if DmLocked and (DmKey = nil) then
    raise Exception.Create('This conversation is locked. Open it again and give your password.');
  // a file attached before the conversation was locked, or unlocked, was
  // sent up the other way
  for I := 0 to Attached.Count - 1 do
    if (Attached.Objects[I].Get('iv', '') <> '') <> DmLocked then
    begin
      if DmLocked then
        raise Exception.Create('A file was attached before this conversation was locked. Take it off and attach it again.')
      else
        raise Exception.Create('A file was attached while this conversation was locked. Take it off and attach it again.');
    end;
  Payload := TJSONObject.Create(['t', 'text', 'text', Words]);
  try
    if DmReply <> nil then
      Payload.Add('re', DmReply.Clone);
    if Attached.Count > 0 then
    begin
      Payload.Strings['t'] := 'file';
      Payload.Add('files', Attached.Clone);
    end;
    Sending := True;
    SentText := Words;
    SentRoom := Room;
    SentAttach := AttachGen;
    SentReplySerial := ReplySerial;
    if DmLocked then
    begin
      Seal(DmKey, MyKeyName, DmKeyName, Payload.AsJSON, Iv, Sealed);
      ApiPostAsync('/api/dm', ['to', Copy(Room, 2, MaxInt), 'iv', Iv, 'data', Sealed, 'files', AttachedTokens(Attached)], @DmSentDone, RoomGen);
    end
    else
      ApiPostAsync('/api/dm', ['to', Copy(Room, 2, MaxInt), 'data', Payload.AsJSON, 'files', AttachedTokens(Attached)], @DmSentDone, RoomGen);
  finally
    Payload.Free;
  end;
end;

procedure TMainForm.DmSentDone(Job: TApiJob);
begin
  Sending := False;
  if Job.Error <> '' then
  begin
    if (Job.Status = 409) and (Job.Tag = RoomGen) then
      OpenRoom(Room);
    SendFailed(Job);
    Exit;
  end;
  if (SentRoom = Room) and not OpeningBusy and (SentReplySerial = ReplySerial) then
    ClearAnswer;
  SentAccepted;
  if (Job.Tag = RoomGen) and InDm then
    LoadDmNews;
end;

procedure TMainForm.SendDmEdit(const Words: string);
var
  Payload: TJSONObject;
  Iv, Data: string;
begin
  if DmLocked and (DmKey = nil) then
    raise Exception.Create('This conversation is locked. Open it again and give your password.');
  // The conversation was unlocked since: sending the edit now would put a
  // message the server could never read where it can read it.
  if EditSealed and not DmLocked then
    raise Exception.Create('This message was sent locked, and the conversation is not locked now. Lock it again to change the message.');
  Payload := DmEditPayload(EditPayload, Words);
  try
    Sending := True;
    SentText := Words;
    SentRoom := Room;
    if DmLocked then
    begin
      Seal(DmKey, MyKeyName, DmKeyName, Payload.AsJSON, Iv, Data);
      ApiPostAsync('/api/dm/edit', ['id', IntToStr(EditingId), 'iv', Iv, 'data', Data], @DmEditDone, RoomGen, '', IntToStr(EditingId));
    end
    else
      ApiPostAsync('/api/dm/edit', ['id', IntToStr(EditingId), 'data', Payload.AsJSON], @DmEditDone, RoomGen, '', IntToStr(EditingId));
  finally
    Payload.Free;
  end;
end;

procedure TMainForm.DmEditDone(Job: TApiJob);
var
  Id: integer;
begin
  Sending := False;
  if Job.Error <> '' then
  begin
    SendFailed(Job);
    Exit;
  end;
  if (Job.Tag <> RoomGen) or not InDm or OpeningBusy then
    Exit;
  Id := StrToIntDef(Job.Context, 0);
  if (EditingId = Id) and (Composer.Text = SentText) then
    StopEdit;
  RefreshDm(Id);
end;

procedure TMainForm.SentAccepted;
begin
  NoticeBar.Hide('send');
  NoticeBar.Hide('send-error');
  if Trim(StringReplace(Drafts.Values[SentRoom], #1, LineEnding, [rfReplaceAll])) = Trim(SentText) then
    Drafts.Values[SentRoom] := '';
  if (Room <> SentRoom) or OpeningBusy then
    Exit;
  if Trim(Composer.Text) = Trim(SentText) then
    Composer.Clear;
  if AttachGen = SentAttach then
    ClearAttached;
end;

procedure TMainForm.AttachButtonClick(Sender: TObject);
var
  Target: TApiTarget;
  Generation: integer;
begin
  Target := ApiTarget;
  Generation := RoomGen;
  if OpenDialog1.Execute and ApiTargetCurrent(Target) and (Generation = RoomGen) then
    AttachFile(OpenDialog1.FileName);
end;

procedure TMainForm.ComposerDropFiles(Sender: TObject; Files: TStrings; X, Y: integer);
var
  Path: string;
begin
  for Path in Files do
    AttachFile(Path);
  FocusComposer;
end;

{ The component found no way to take drops here (a widgetset without
  support, or a second helper on the box): said where the typing note goes. }
procedure TMainForm.DropError(Sender: TObject; const Message: string);
begin
  TypingLabel.Caption := 'Dropping files: ' + Message;
end;

{ Uploaded now, sent with the next message; sealed first in a locked
  conversation. }
procedure TMainForm.AttachFile(const FileName: string);
var
  Plain, Data: TBytesStream;
  Iv: string;
  Context: TJSONObject;
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if OpeningBusy or not CanTalk or (EditingId > 0) then Exit;
  if InDm and DmLocked and (DmKey = nil) then
  begin
    NoticeToast.Show('This conversation is locked. Open it again and give your password, then attach the file.');
    Exit;
  end;
  Plain := TBytesStream.Create;
  Context := TJSONObject.Create;
  try
    try
      Plain.LoadFromFile(FileName);
      if InDm and DmLocked and (DmKey <> nil) then
      begin
        Data := TBytesStream.Create(SealBytes(DmKey, Copy(Plain.Bytes, 0, Plain.Size), Iv));
        try
          Context.Add('iv', Iv);
          Context.Add('name', ExtractFileName(FileName));
          Context.Add('size', Plain.Size);
          ApiUploadAsync('sealed', Data, True, False, ExpiryValue(FileExpiryBox.ItemIndex), '', @UploadDone, UploadGen, Context.AsJSON);
        finally
          Data.Free;
        end;
      end
      else
        ApiUploadAsync(ExtractFileName(FileName), Plain, False, False,
          ExpiryValue(FileExpiryBox.ItemIndex), '', @UploadDone, UploadGen);
      Inc(Uploading);
      ShowRoomMenu;
    except
      on E: Exception do ShowError(E, 'attachfile');
    end;
  finally
    Context.Free;
    Plain.Free;
  end;
end;

procedure TMainForm.UploadDone(Job: TApiJob);
var
  Answer, Context: TJSONObject;
begin
  if Job.Tag <> UploadGen then Exit;
  Dec(Uploading);
  ShowRoomMenu;
  try
    Answer := Job.ObjectJSON;
    try
      if Job.Context <> '' then
      begin
        Context := JSONObject(Job.Context);
        try
          Answer.Add('iv', Context.Get('iv', ''));
          Answer.Strings['name'] := Context.Get('name', '');
          Answer.Int64s['size'] := Context.Get('size', int64(0));
        finally
          Context.Free;
        end;
      end;
      Attached.Add(Answer);
      Answer := nil;
      ShowAttached;
    finally
      Answer.Free;
    end;
  except
    on E: Exception do ShowError(E, 'attachfile');
  end;
end;

{ Tells the server, at most every three seconds, that this member types. }
{ Enter sends and Shift+Enter puts its own line break (KeyDown): the key
  itself must not reach the box. }
procedure TMainForm.ComposerKeyPress(Sender: TObject; var Key: char);
begin
  if Key in [#10, #13] then
    Key := #0;
end;

procedure TMainForm.ComposerChange(Sender: TObject);
begin
  if SignInEnded then Exit;
  if not CanTalk then
    Exit;
  // GTK puts the Enter that sent in as a line break all the same, after
  // the key handlers; it is taken out again while the send is on its way.
  if Sending and (Composer.Text = SentText + LineEnding) then
  begin
    Composer.Text := SentText;
    Composer.SelStart := UTF8Length(SentText);
    Exit;
  end;
  UpdateSuggest;
  if OpeningBusy or (EditingId > 0) or (Composer.Text = '') or (GetTickCount64 - LastTyping < 3000) then
    Exit;
  LastTyping := GetTickCount64;
  // Only a hint for the others: no answer is waited for, and a notice
  // still waiting gives way to the next.
  if InDm then
    ApiPostAsync('/api/dm/typing', ['to', Copy(Room, 2, MaxInt)], nil, 0, 'typing')
  else
    ApiPostAsync('/api/typing', ['room', Room], nil, 0, 'typing');
end;

{ The message the menu was opened on, found again by its id: older messages
  may have come in above it since, moving it down Shown. }
function TMainForm.MenuMessage: TJSONObject;
var
  I: integer;
begin
  Result := nil;
  if (MenuId = 0) or (MenuRoom <> Room) or (MenuEpoch <> ApiEpoch) then
    Exit;
  for I := 0 to Shown.Count - 1 do
    if TJSONObject(Shown[I]).Get('id', 0) = MenuId then
    begin
      MenuEntry := I;
      Exit(TJSONObject(Shown[I]));
    end;
end;

{ The menu acts on the message under the pointer. }
procedure TMainForm.MessageMenuPopup(Sender: TObject);
var
  P: TPoint;
  Msg: TJSONObject;
  Mine: boolean;
begin
  P := Messages.ScreenToClient(MessageMenu.PopupPoint);
  MenuEntry := Messages.EntryAt(P.X, P.Y);
  MenuId := 0;
  MenuRoom := Room;
  MenuEpoch := ApiEpoch;
  if (MenuEntry >= 0) and (MenuEntry < Shown.Count) then
    MenuId := TJSONObject(Shown[MenuEntry]).Get('id', 0);
  Msg := MenuMessage;
  Mine := (Msg <> nil) and SameText(Msg.Get('name', ''), MyName) and not Msg.Get('deleted', False);
  ReactItem.Enabled := (Msg <> nil) and not OpeningBusy and not Msg.Get('deleted', False) and ((InDm and SiteCan('react')) or (not InDm and RoomCan('react')));
  FillReactMenu(ReactItem, MyReactions, Msg, @ReactClick);
  AnswerItem.Enabled := (Msg <> nil) and CanTalk and not OpeningBusy and (EditingId = 0) and (Msg.Get('body', '') <> '');
  PinItem.Enabled := (Msg <> nil) and not InDm and not Msg.Get('deleted', False) and RoomCan('pin');
  if (Msg <> nil) and Msg.Get('pinned', False) then
    PinItem.Caption := 'Unpin'
  else
    PinItem.Caption := 'Pin';
  ThreadItem.Enabled := (Msg <> nil) and not InDm;
  CopyItem.Enabled := Msg <> nil;
  CopyLinkItem.Visible := not InDm;
  CopyLinkItem.Enabled := Msg <> nil;
  EditItem.Enabled := Mine and SiteCan('edit-own') and not OpeningBusy and (not InDm or (Msg.Find('dm_payload') is TJSONObject));
  // A moderator takes down anyone's.
  DeleteItem.Enabled := MayDeleteMessage(Msg, MyName, InDm, RoomCan('delete-any'), SiteCan('delete-own'));
end;

procedure TMainForm.ReactClick(Sender: TObject);
begin
  if MenuMessage = nil then
    Exit;
  ReactToMessage(MenuMessage.Get('id', 0), TMenuItem(Sender).Caption);
end;

procedure TMainForm.ReactToMessage(Id: integer; const Reaction: string);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if OpeningBusy or (Id <= 0) or (Reaction = '') then
    Exit;
  if InDm then
  begin
    if SiteCan('react') then
      ApiPostAsync('/api/dm/react', ['id', IntToStr(Id), 'r', Reaction], @DmReactDone, RoomGen, '', IntToStr(Id));
  end
  else if RoomCan('react') then
    PostThenSync('/api/react', ['id', IntToStr(Id), 'r', Reaction]);
end;

procedure TMainForm.DmReactDone(Job: TApiJob);
begin
  if Job.Error <> '' then
    ShowJobError(Job, 'dmreactdone')
  else if Job.Tag = RoomGen then
    RefreshDm(StrToIntDef(Job.Context, 0));
end;

procedure TMainForm.RefreshDm(Id: integer);
var
  I: integer;
begin
  if not InDm or OpeningBusy or (Id <= 0) then
    Exit;
  for I := 0 to Shown.Count - 1 do
    if TJSONObject(Shown[I]).Get('id', 0) = Id then
    begin
      ApiGetAsync(DmAsk(Copy(Room, 2, MaxInt), daOne, Id), @DmRefreshDone, RoomGen, 'dm-refresh:' + IntToStr(Id));
      Exit;
    end;
end;

procedure TMainForm.DmRefreshDone(Job: TApiJob);
var
  List: TJSONArray;
  Msg: TJSONObject;
  I: integer;
  WasFilling: boolean;
begin
  if (Job.Tag <> RoomGen) or not InDm or OpeningBusy or (Job.Error <> '') then
    Exit;
  List := Job.ArrayJSON;
  try
    if (List.Count <> 1) or not (List[0] is TJSONObject) then
      Exit;
    Msg := TJSONObject(List[0]);
    for I := 0 to Shown.Count - 1 do
      if TJSONObject(Shown[I]).Get('id', 0) = Msg.Get('id', 0) then
      begin
        Shown[I] := Readable(Msg);
        WasFilling := Filling;
        Filling := True;
        try
          PutEntry(I);
        finally
          Filling := WasFilling;
        end;
        Break;
      end;
  finally
    List.Free;
  end;
end;

procedure TMainForm.ShowAnswer;
begin
  AnswerPanel.Visible := (DmReply <> nil) and (EditingId = 0);
  if DmReply <> nil then
  begin
    AnswerLabel.Caption := 'Answering ' + DmReply.Get('from', '') + ': ' + ReplyWords(DmReply);
    AnswerLabel.Hint := AnswerLabel.Caption;
  end
  else
  begin
    AnswerLabel.Caption := '';
    AnswerLabel.Hint := '';
  end;
  ComposerPanel.Height := ComposerBase + AttachRow.Height;
  if AnswerPanel.Visible then
    ComposerPanel.Height := ComposerPanel.Height + AnswerPanel.Height;
end;

procedure TMainForm.ClearAnswer;
begin
  FreeAndNil(DmReply);
  Inc(ReplySerial);
  ShowAnswer;
end;

procedure TMainForm.AnswerClick(Sender: TObject);
var
  Msg, Reply: TJSONObject;
begin
  Msg := MenuMessage;
  if OpeningBusy or not CanTalk or (EditingId > 0) or (Msg = nil) or (Msg.Get('body', '') = '') then
    Exit;
  Reply := TJSONObject.Create(['id', Msg.Get('id', 0), 'from', Msg.Get('name', ''), 'text', DmReplyText(DmActionText(Msg.Get('name', ''), Msg.Get('body', '')))]);
  try
    ClearAnswer;
    DmReply := CheckedDmReply(Reply);
    ShowAnswer;
  finally
    Reply.Free;
  end;
  FocusComposer;
end;

procedure TMainForm.CancelAnswerClick(Sender: TObject);
begin
  ClearAnswer;
  FocusComposer;
end;

procedure TMainForm.PinItemClick(Sender: TObject);
begin
  if MenuMessage = nil then
    Exit;
  PostThenSync('/api/pin', ['id', IntToStr(MenuMessage.Get('id', 0))]);
end;

{ What the Room menu offers: a room is searched and has pins, a private
  conversation can be locked or unlocked. }
procedure TMainForm.ShowRoomMenu;
var
  Priv: boolean;
begin
  ActFind.Enabled := True;
  if InDm then
  begin
    ActFind.Caption := 'Search this conversation...';
    ActFind.Hint := 'Search this conversation for words (Ctrl+Shift+F)';
  end
  else
  begin
    ActFind.Caption := 'Search the channel''s history...';
    ActFind.Hint := 'Ask the server for every message in this channel with these words (Ctrl+Shift+F)';
  end;
  ActPins.Enabled := (Room <> '') and not InDm;
  ActLock.Enabled := InDm and not OpeningBusy;
  DeleteDmItem.Enabled := InDm and not OpeningBusy and not RowActionBusy;
  // What the server says this member may do in the room (the web page
  // shows the same things); a conversation has no card and no such items.
  Priv := (Card <> nil) and Card.Get('private', False);
  TopicItem.Enabled := (Card <> nil) and RoomCan('set-topic');
  InviteItem.Enabled := Priv and RoomCan('invite');
  KickItem.Enabled := Priv and RoomCan('kick');
  LeaveItem.Enabled := not OpeningBusy and not RowActionBusy and (Card <> nil) and Card.Get('following', False) and (Card.Get('kind', '') <> 'shelf');
  if Priv then
    LeaveItem.Caption := 'Leave this channel...'
  else
    LeaveItem.Caption := 'Leave this channel';
  CanTalk := not ChatOff and (Room <> '') and (InDm or (Card = nil) or Card.Get('can_start', True));
  WhyNot := '';
  if not CanTalk and (Card <> nil) then
    WhyNot := Card.Get('why_not', 'Posting is not open to you here.');
  ActSend.Enabled := CanTalk and not OpeningBusy and (Uploading = 0);
  AttachButton.Enabled := CanTalk and not OpeningBusy and (EditingId = 0) and RoomCan('upload');
  if DmLocked then
    ActLock.Caption := 'Unlock this conversation'
  else
    ActLock.Caption := 'Lock this conversation';
end;

{ /msg name text, as on the web page: the conversation opens, and the text
  goes to it. }
procedure TMainForm.StartConversation(const Command: string);
var
  Rest, Who: string;
begin
  Rest := Trim(Copy(Command, Pos(' ', Command) + 1, MaxInt));
  Who := Rest;
  if Pos(' ', Rest) > 0 then
    Who := Copy(Rest, 1, Pos(' ', Rest) - 1);
  Rest := Trim(Copy(Rest, Length(Who) + 1, MaxInt));
  Who := Who.TrimLeft(['@']);
  if Who = '' then
    raise Exception.Create('Use: /msg name text');
  Composer.Clear;
  AfterOpen := Rest;
  AfterOpenFor := '@' + Who;
  OpenRoom('@' + Who);
end;

procedure TMainForm.ActFindHereExecute(Sender: TObject);
begin
  Messages.SetFocus;
  Messages.ShowFindBar;
end;

{ Locked from now on, or open again; both members need keys, which the
  server checks. }
procedure TMainForm.ActLockExecute(Sender: TObject);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if not InDm then
    Exit;
  ApiPostAsync('/api/dm/lock', ['with', Copy(Room, 2, MaxInt), 'on', IntToStr(Ord(not DmLocked))], @LockDone, RoomGen);
end;

procedure TMainForm.LockDone(Job: TApiJob);
begin
  if Job.Error <> '' then
    ShowJobError(Job, 'lockdone')
  else if Job.Tag = RoomGen then
    OpenRoom(Room);
end;

{ A name in the People panel opens a private conversation with them. }
procedure TMainForm.MemberListClick(Sender: TObject);
begin
  if (MemberList.ItemIndex >= 0) and (MemberList.ItemIndex < MemberNames.Count) and (MemberNames[MemberList.ItemIndex] <> '') and not
    SameText(MemberNames[MemberList.ItemIndex], MyName) then
    OpenRoom('@' + MemberNames[MemberList.ItemIndex]);
end;

procedure TMainForm.ActFindExecute(Sender: TObject);
var
  Picked, Link: string;
  Generation: integer;
begin
  if OpeningBusy then
    Exit;
  if InDm and DmLocked then
  begin
    NoticeToast.Show('Search is not possible in a locked conversation because the server cannot read it.');
    Exit;
  end;
  Generation := RoomGen;
  Picked := Room;
  if FindInRoom(Picked, Link, @MessagesResource) then
    if Generation = RoomGen then
      FollowLink(Picked, Link);
end;

{ What a find or the pins gave back: a room, a message in it, or a thread. }
procedure TMainForm.FollowLink(var Picked: string; const Link: string);
var
  Parts: TStringArray;
begin
  if Link.StartsWith('msg:') then
  begin
    Parts := Link.Split([':']);
    if Length(Parts) = 3 then
      JumpToMessage(Parts[1], StrToIntDef(Parts[2], 0));
  end
  else if Link.StartsWith('thread:') then
  begin
    // thread:room:id from a search; thread:id from the pins of this room
    Parts := Link.Split([':']);
    if Length(Parts) = 3 then
      Picked := Parts[1];
    if (Picked <> '') and (Picked <> Room) then
    begin
      ThreadAfter := StrToIntDef(Parts[High(Parts)], 0);
      OpenRoom(Picked);
    end
    else
      OpenThreadOn(StrToIntDef(Parts[High(Parts)], 0));
  end
  else if (Picked <> '') and (Picked <> Room) then
    OpenRoom(Picked);
end;

{ The room opened, older messages read in until the one wanted is on show
  (a page or forty), the view put on it and the message lit for a moment. }
procedure TMainForm.JumpToMessage(const Slug: string; Id: integer);
begin
  JumpId := Id;
  JumpPages := 0;
  if Slug <> Room then
    OpenRoom(Slug)
  else
    JumpStep;
end;

{ The message wanted is on show, or another page is read for it, forty at
  most. }
procedure TMainForm.JumpStep;
var
  I, J: integer;
begin
  I := -1;
  for J := 0 to Shown.Count - 1 do
    if TJSONObject(Shown[J]).Get('id', 0) = JumpId then
      I := J;
  if I < 0 then
  begin
    if MoreBefore and (JumpPages < 40) then
    begin
      Inc(JumpPages);
      LoadOlder;
    end
    else
    begin
      JumpId := 0;
      NoticeToast.Show('That message is further back than this reads. The channel is open at its end.');
    end;
    Exit;
  end;
  if MarkId > 0 then
    MarkTick(nil);
  MarkId := JumpId;
  JumpId := 0;
  PutEntry(I);
  ScrollToEntry(I);
  MarkTimer.Enabled := True;
end;

procedure TMainForm.MarkTick(Sender: TObject);
var
  I, Was: integer;
begin
  MarkTimer.Enabled := False;
  Was := MarkId;
  MarkId := 0;
  for I := 0 to Shown.Count - 1 do
    if TJSONObject(Shown[I]).Get('id', 0) = Was then
      PutEntry(I);
end;

procedure TMainForm.ActPinsExecute(Sender: TObject);
var
  Picked, Link: string;
  Generation: integer;
begin
  if InDm then
    Exit;
  Picked := Room;
  Generation := RoomGen;
  try
    if ShowPins(Picked, Link, @MessagesResource) and (Generation = RoomGen) then
      FollowLink(Picked, Link);
  except
    on E: Exception do
      ShowError(E, 'actpinsexecute');
  end;
end;

procedure TMainForm.ActSettingsExecute(Sender: TObject);
begin
  try
    EditSettings(AutoAway, TextScale);
    ApplyScale;
    SaveAccount;
    // Laid out afresh at the new size: back to the newest messages.
    Messages.ScrollTo(MaxInt);
  except
    on E: Exception do
      ShowError(E, 'actsettingsexecute');
  end;
end;

procedure TMainForm.UserInput(Sender: TObject; var Msg: TLMessage);
begin
  LastInput := GetTickCount64;
  if Idle and not IdleBusy then
  begin
    IdleBusy := True;
    ApiPostAsync('/api/prefs', ['idle', '0'], @IdleDone, 0, 'idle');
  end;
end;

{ Away or back was told; shown so once the server agreed. }
procedure TMainForm.IdleDone(Job: TApiJob);
begin
  IdleBusy := False;
  if Job.Error = '' then
    Idle := Job.Tag = 1;
end;

procedure TMainForm.ThreadItemClick(Sender: TObject);
begin
  if MenuMessage <> nil then
    OpenThreadOn(MenuMessage.Get('id', 0));
end;

procedure TMainForm.CopyItemClick(Sender: TObject);
begin
  if MenuMessage = nil then
    Exit;
  // What was typed, Markdown and all; a private message has only its words.
  if MenuMessage.Find('body') <> nil then
    Clipboard.AsText := MenuMessage.Get('body', '')
  else
    Clipboard.AsText := Messages.GetPlainText(MenuEntry);
  NoticeToast.Show('Copied.');
end;

procedure TMainForm.EditItemClick(Sender: TObject);
begin
  if MenuMessage <> nil then
    StartEdit(MenuEntry);
end;

procedure TMainForm.CopyLinkItemClick(Sender: TObject);
begin
  if (MenuMessage <> nil) and not InDm then
  begin
    Clipboard.AsText := MessageLink(Server, MenuMessage.Get('id', 0));
    NoticeToast.Show('Link copied.');
  end;
end;

procedure TMainForm.DeleteItemClick(Sender: TObject);
var
  Id, Epoch: integer;
  Target, Words: string;
  PrivateMessage: boolean;
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if not MayDeleteMessage(MenuMessage, MyName, InDm, RoomCan('delete-any'), SiteCan('delete-own')) then
    Exit;
  Id := MenuMessage.Get('id', 0);
  Target := Room;
  Epoch := ApiEpoch;
  PrivateMessage := InDm;
  Words := 'Delete this message?';
  if PrivateMessage then
    Words := 'Delete this message for both of you, including its files? This cannot be undone.';
  if MessageDlg(Words, mtConfirmation, [mbYes, mbNo], 0, mbNo) <> mrYes then
    Exit;
  if Epoch <> ApiEpoch then
    Exit;
  if PrivateMessage then
    ApiPostAsync('/api/dm/delete', ['id', IntToStr(Id)], @DmDeleteDone, Id, '', Target)
  else
    PostThenSync('/api/delete', ['id', IntToStr(Id)]);
end;

procedure TMainForm.DmDeleteDone(Job: TApiJob);
begin
  if Job.Error <> '' then
    ShowJobError(Job, 'dmdeletedone')
  else if InDm and SameText(Room, Job.Context) then
    RemoveDmMessage(Job.Tag);
  RefreshRooms;
end;

procedure TMainForm.RemoveDmMessage(Id: integer);
var
  Index: integer;
  Wanted: string;
begin
  if not InDm then
    Exit;
  // Discard reads taken before the deletion, including an older page.
  if OpeningBusy then
  begin
    Wanted := Opening;
    OpenRoom(Wanted);
  end
  else
  begin
    Inc(RoomGen);
    WipeBytes(KeyWrap);
    WipeText(KeyPassword);
    WipeText(KeyAnswer);
    SyncBusy := False;
    SyncAgain := False;
    DmNewsBusy := False;
    Fetching := False;
  end;
  Index := RemoveMessage(Shown, Id);
  if Index >= 0 then
  begin
    Filling := True;
    try
      Messages.DeleteBlock(Index);
      if Shown.Count = 0 then
        Render
      else if Index < Shown.Count then
        PutEntry(Index);
    finally
      Filling := False;
    end;
  end;
  if not OpeningBusy then
    if (Shown.Count = 0) and MoreBefore then
      OpenRoom(Room)
    else
    begin
      DmNews;
      Sync;
    end;
end;

{ The message goes back into the box; Send saves it, Esc lets it be. }
procedure TMainForm.StartEdit(I: integer);
var
  Msg: TJSONObject;
begin
  if OpeningBusy or not SiteCan('edit-own') or (I < 0) or (I >= Shown.Count) then
    Exit;
  Msg := TJSONObject(Shown[I]);
  if not SameText(Msg.Get('name', ''), MyName) or Msg.Get('deleted', False) then
    Exit;
  if InDm and not (Msg.Find('dm_payload') is TJSONObject) then
    Exit;
  if EditingId = 0 then
    DraftBeforeEdit := Composer.Text;
  FreeAndNil(EditPayload);
  if InDm then
    EditPayload := Msg.Objects['dm_payload'].Clone as TJSONObject;
  EditSealed := Msg.Get('sealed', False);
  EditingId := Msg.Get('id', 0);
  Composer.Text := Msg.Get('body', '');
  Composer.SelStart := UTF8Length(Composer.Text);
  TypingLabel.Caption := 'Editing your message. Esc stops.';
  ShowAnswer;
  ShowRoomMenu;
  Composer.SetFocus;
end;

procedure TMainForm.StopEdit;
begin
  Composer.Text := DraftBeforeEdit;
  Composer.SelStart := UTF8Length(Composer.Text);
  EditingId := 0;
  FreeAndNil(EditPayload);
  TypingLabel.Caption := '';
  ShowAnswer;
  ShowRoomMenu;
end;

{ One panel on the right at a time, as on the web page. }
procedure TMainForm.OpenThreadOn(Id: integer);
begin
  ThreadPane.SetMember(MyName, RoomCan('react'), RoomCan('pin'), RoomCan('delete-any'), SiteCan('edit-own'), SiteCan('delete-own'), MyReactions);
  ThreadPane.OpenThread(Id);
  if NarrowMode then
  begin
    // The thread takes the room's place; closing it brings the room back.
    ThreadPane.Align := alClient;
    RoomPanel.Visible := False;
  end
  else
  begin
    ThreadPane.Align := alRight;
    Splitter3.Visible := True;
    Splitter3.Left := ThreadPane.Left - Splitter3.Width;
  end;
  ShowPeople;
  ShowConnection;
end;

procedure TMainForm.Notify(const Title, Words: string);
begin
  Tray.BalloonTitle := Title;
  Tray.BalloonHint := Words;
  Tray.ShowBalloonHint;
end;

procedure TMainForm.NotifyRooms(List: TJSONArray; Serial: integer);
var
  Target: string;
begin
  if not NoticePending or (Serial <> NoticeSerial) then
    Exit;
  NoticePending := False;
  Target := NoticeRoom(NoticeBefore, List, NoticeChannel);
  FreeAndNil(NoticeBefore);
  if (Target = '') or (Application.Active and (WindowState <> wsMinimized)) then
    Exit;
  PendingTarget := Target;
  if NoticeChannel <> '' then
    Notify('Exedra', 'You were mentioned in #' + Target + '.')
  else
    Notify('Exedra', 'Someone mentioned you, or invited you into a channel.');
end;

{ A click on the tray brings the window, and opens where the last note
  came from, when there was one since the window was last looked at. }
procedure TMainForm.TrayClick(Sender: TObject);
var
  Target: string;
begin
  Show;
  if WindowState = wsMinimized then
    WindowState := wsNormal;
  Application.BringToFront;
  Target := PendingTarget;
  PendingTarget := '';
  if (Target <> '') and (Target <> Room) then
  try
    OpenRoom(Target);
  except
    on E: Exception do
      ShowError(E, 'trayclick');
  end;
end;

{ The tray icon with the unread count on it, drawn over the program's own
  picture; the plain picture again at zero. }
procedure TMainForm.TrayBadge(Count: integer);
var
  Png: TPortableNetworkGraphic;
  Img: TLazIntfImage;
  Face: TBitmap;
  X, Y, R, CX, CY: integer;
  C: TFPColor;
  Words: string;
begin
  if Count < 0 then
    Count := 0;
  // past 99 the icon says so with "99", whatever the number
  if Count > 99 then
    Count := 99;
  if Count = TrayCount then
    Exit;
  TrayCount := Count;
  if Count <= 0 then
  begin
    Tray.Icon.Assign(Application.Icon);
    Exit;
  end;
  Words := IntToStr(Count);
  Png := TPortableNetworkGraphic.Create;
  Face := TBitmap.Create;
  Img := nil;
  try
    Png.LoadFromResourceName(HInstance, 'LOGO');
    Img := Png.CreateIntfImage;
    // the badge, drawn opaque on a bitmap, then copied in with full alpha
    Face.SetSize(Img.Width, Img.Height);
    Face.Canvas.Brush.Color := clWhite;
    Face.Canvas.FillRect(0, 0, Img.Width, Img.Height);
    R := Img.Width * 2 div 7;
    CX := Img.Width - R - 1;
    CY := Img.Height - R - 1;
    Face.Canvas.Brush.Color := $2727D6;
    Face.Canvas.Pen.Color := $2727D6;
    Face.Canvas.Ellipse(CX - R, CY - R, CX + R, CY + R);
    Face.Canvas.Font.Color := clWhite;
    Face.Canvas.Font.Style := [fsBold];
    Face.Canvas.Font.Height := -(R + R div 3);
    Face.Canvas.Brush.Style := bsClear;
    Face.Canvas.TextOut(CX - Face.Canvas.TextWidth(Words) div 2, CY - Face.Canvas.TextHeight(Words) div 2, Words);
    for Y := CY - R to CY + R do
      for X := CX - R to CX + R do
        if (X >= 0) and (Y >= 0) and (X < Img.Width) and (Y < Img.Height) and (Sqr(X - CX) + Sqr(Y - CY) <= Sqr(R)) then
        begin
          C := TColorToFPColor(ColorToRGB(Face.Canvas.Pixels[X, Y]));
          C.Alpha := alphaOpaque;
          Img.Colors[X, Y] := C;
        end;
    Png.LoadFromIntfImage(Img);
    Tray.Icon.Assign(Png);
  finally
    Img.Free;
    Face.Free;
    Png.Free;
  end;
end;

function TMainForm.RoomItem(At: integer; const Title: string; Handler: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(Self);
  Result.Caption := Title;
  Result.OnClick := Handler;
  RoomMenu.Insert(At, Result);
end;

{ What the room's card says this member may do there; everything until a
  card has been read, the server has the last word anyway. }
function TMainForm.RoomCan(const Perm: string): boolean;
begin
  Result := (Card = nil) or (Card.Find('can') = nil) or Card.Objects['can'].Get(Perm, False);
end;

function TMainForm.SiteCan(const Perm: string): boolean;
begin
  Result := (MyCan = nil) or (MyCan.IndexOf(Perm) >= 0);
end;

{ A slash command in the room on show, its answer in a box; the People
  panel is read again since most of them change who is in the room. }
procedure TMainForm.RunCommand(const Line: string);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  ApiPostAsync('/api/post', ['room', Room, 'parent', '', 'body', Line, 'files', ''], @CommandDone, RoomGen);
end;

procedure TMainForm.CommandDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if Job.Error <> '' then
  begin
    ShowJobError(Job, 'commanddone');
    Exit;
  end;
  Answer := Job.ObjectJSON;
  try
    if Answer.Get('info', '') <> '' then
      NoticeToast.Show(Answer.Get('info', ''));
  finally
    Answer.Free;
  end;
  if Job.Tag = RoomGen then
  begin
    ReadStaff;
    Sync;
  end;
end;

{ A small change told to the server (a reaction, a pin, a deletion): the
  room and the thread are read again once it is in. }
procedure TMainForm.PostThenSync(const Path: string; const Fields: array of string);
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  ApiPostAsync(Path, Fields, @PostedDone, RoomGen);
end;

procedure TMainForm.PostedDone(Job: TApiJob);
begin
  if Job.Error <> '' then
    ShowJobError(Job, 'posteddone')
  else if Job.Tag = RoomGen then
  begin
    Sync;
    if ThreadPane.Visible then
      ThreadPane.Refresh;
  end;
end;

{ A callback raised, which is a fault in this program, not in the server. }
procedure TMainForm.ApiFailed(const Words: string);
begin
  if OpeningBusy then RoomFailed(Words);
  DmNewsBusy := False;
  if MyName = '' then ConnectionLost(0);
  NoticeBar.Show(Words, mtError, [], 'apifailed');
end;

{ Room > New room: private unless this member may open public channels
  (the server decides; members open private rooms, admins channels). }
procedure TMainForm.NewRoomClick(Sender: TObject);
var
  Slug, Topic: string;
  Priv: boolean;
  Target: TApiTarget;
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  Target := ApiTarget;
  if not AskNewRoom(SiteCan('create-channel'), SiteCan('create-private'), Slug, Topic, Priv) then
    Exit;
  if not ApiTargetCurrent(Target) then Exit;
  ApiPostAsync('/api/room/create', ['slug', Slug, 'topic', Topic, 'private', IntToStr(Ord(Priv))], @NewRoomDone, RoomGen, '', Slug);
end;

procedure TMainForm.NewRoomDone(Job: TApiJob);
var
  Answer: TJSONObject;
begin
  if Job.Error <> '' then
  begin
    ShowJobError(Job, 'newroomclick');
    Exit;
  end;
  Answer := Job.ObjectJSON;
  try
    if Job.Tag = RoomGen then OpenRoom(Answer.Get('slug', Job.Context));
  finally
    Answer.Free;
  end;
end;

procedure TMainForm.TopicClick(Sender: TObject);
var
  Topic: string;
  Target: TApiTarget;
  Generation: integer;
begin
  if SignInEnded or ReauthPending or ChatOff then Exit;
  if InDm or (Card = nil) then
    Exit;
  Topic := Card.Get('topic', '');
  Target := ApiTarget;
  Generation := RoomGen;
  if not AskRoomTopic(Card.Get('title', Room), Topic) then
    Exit;
  if not ApiTargetCurrent(Target) or (Generation <> RoomGen) then Exit;
  ApiPostAsync('/api/topic', ['room', Room, 'topic', Topic], @TopicDone, RoomGen);
end;

procedure TMainForm.TopicDone(Job: TApiJob);
begin
  if Job.Error <> '' then
    ShowJobError(Job, 'topicdone')
  else if Job.Tag = RoomGen then
    ReadRoomCard;
end;

{ Into a private room: a name, with the people online and the people this
  member has talked to offered. }
procedure TMainForm.InviteClick(Sender: TObject);
var
  Names: TStringList;
  Item: TJSONEnum;
  Who: string;
  Target: TApiTarget;
  Generation: integer;
begin
  if InDm or (Card = nil) then
    Exit;
  Names := TStringList.Create;
  Target := ApiTarget;
  Generation := RoomGen;
  try
    Names.Sorted := True;
    Names.Duplicates := dupIgnore;
    for Item in HereSeen do
      Names.Add(TJSONObject(Item.Value).Get('name', ''));
    for Item in DmsSeen do
      Names.Add(TJSONObject(Item.Value).Get('name', ''));
    Who := Trim(InputComboEx('Invite someone', 'Their name (people online, and people you have talked to, are listed):', Names, True));
  finally
    Names.Free;
  end;
  Who := Who.TrimLeft(['@']);
  if not ApiTargetCurrent(Target) or (Generation <> RoomGen) then Exit;
  if Who <> '' then
    RunCommand('/invite ' + Who);
end;

{ Out of a private room; an invite brings them back. }
procedure TMainForm.KickClick(Sender: TObject);
var
  Names: TStringList;
  Item: TJSONEnum;
  Who: string;
  Target: TApiTarget;
  Generation: integer;
begin
  if InDm or (Card = nil) then
    Exit;
  Names := TStringList.Create;
  Target := ApiTarget;
  Generation := RoomGen;
  try
    for Item in Staff do
      if TJSONObject(Item.Value).Get('name', '') <> MyName then
        Names.Add(TJSONObject(Item.Value).Get('name', ''));
    Who := Trim(InputComboEx('Take someone out', 'Who leaves this channel (an invite brings them back):', Names, True));
  finally
    Names.Free;
  end;
  Who := Who.TrimLeft(['@']);
  if not ApiTargetCurrent(Target) or (Generation <> RoomGen) then Exit;
  if Who <> '' then
    RunCommand('/kick ' + Who);
end;

{ Room > Leave: the room goes from the list; a private one is closed until
  someone invites this member again, so that one asks. }
procedure TMainForm.LeaveClick(Sender: TObject);
begin
  if InDm or (Card = nil) then
    Exit;
  ActOnRow(Room, raLeave);
end;

{ Code: fences round what is selected, or an empty pair with the caret
  between them; lines inside go in with Shift+Enter. }
procedure TMainForm.CodeButtonClick(Sender: TObject);
var
  At: integer;
  Sel: string;
begin
  if not CanTalk then
    Exit;
  At := Composer.SelStart;
  Sel := Composer.SelText;
  Composer.SelText := '```' + LineEnding + Sel + LineEnding + '```';
  Composer.SelStart := At + 3 + Length(LineEnding) + UTF8Length(Sel);
  FocusComposer;
end;

{ Narrower than two columns need, the window shows one: the room, with the
  room list or a thread taking its place while wanted.  Wide again, the
  columns come back as they were. }
procedure TMainForm.FormResize(Sender: TObject);
begin
  ApplyLayout;
end;

procedure TMainForm.ApplyLayout;
const
  cNarrow = 600;
var
  Was: boolean;
begin
  Was := NarrowMode;
  NarrowMode := ClientWidth < cNarrow;
  if NarrowMode = Was then
    Exit;
  if NarrowMode then
  begin
    WideListWidth := RoomList.Width;
    Splitter1.Visible := False;
    Splitter3.Visible := False;
    ListInFront := False;
    RoomList.Visible := False;
    if ThreadPane.Visible then
    begin
      ThreadPane.Align := alClient;
      RoomPanel.Visible := False;
    end
    else
      RoomPanel.Visible := True;
  end
  else
  begin
    ListInFront := False;
    RoomList.Align := alLeft;
    RoomList.Width := WideListWidth;
    RoomList.Visible := True;
    Splitter1.Visible := True;
    Splitter1.Left := RoomList.Width;
    RoomPanel.Visible := True;
    ThreadPane.Align := alRight;
    if ThreadPane.Visible then
    begin
      Splitter3.Visible := True;
      Splitter3.Left := ThreadPane.Left - Splitter3.Width;
    end;
  end;
  ShowHeader(HeadPic, HeadTitle, HeadNote);
  ShowPeople;
end;

{ In one column: the room list over everything, or the room again. }
procedure TMainForm.ShowList(InFront: boolean);
begin
  if not NarrowMode then
    Exit;
  ListInFront := InFront;
  if InFront then
  begin
    if ThreadPane.Visible then
      ThreadClosed(nil);
    RoomPanel.Visible := False;
    RoomList.Align := alClient;
    RoomList.Visible := True;
  end
  else
  begin
    RoomList.Visible := False;
    RoomList.Align := alLeft;
    RoomPanel.Visible := not ThreadPane.Visible;
  end;
end;

{ The link in the header, in one column: Rooms brings the list. }
procedure TMainForm.HeaderLinkClick(Sender: TObject; const LinkName: string);
begin
  if LinkName = 'rooms:' then
    ShowList(True);
end;

{ The text size from Settings: the messages and the thread at that scale,
  the boxes typed into with a font to match. }
procedure TMainForm.ApplyScale;
var
  Pt: integer;
begin
  Messages.HTMLScale := TextScale;
  ThreadPane.Replies.HTMLScale := TextScale;
  if TextScale = 100 then
    Pt := 0
  else
  begin
    Pt := Screen.SystemFont.Size;
    if Pt <= 0 then
      Pt := 10;
    Pt := Round(Pt * TextScale / 100);
  end;
  Composer.Font.Size := Pt;
  ThreadPane.ReplyBox.Font.Size := Pt;
end;

{ Every color mixed from the system's: again, after its theme changed. }
procedure TMainForm.Retheme;
begin
  ThemePaper := ColorToRGB(clWindow);
  ThemeInk := ColorToRGB(clWindowText);
  StripeMemo(Messages);
  SizeExpiryBox(FileExpiryBox);
  RoomList.Color := Mix(clWindow, clWindowText, 0.035);
  HeaderRule.Pen.Color := Mix(RoomPanel.Color, InkOf(RoomHeader.Font.Color), 0.2);
  HeaderRule.Brush.Color := HeaderRule.Pen.Color;
  ShowHeader(HeadPic, HeadTitle, HeadNote);
  ShowRooms;
  ShowPeople;
  ThreadPane.Retheme;
  Invalidate;
end;

{ Who is in the room, or runs it; an empty list when the server would not say. }
procedure TMainForm.ReadStaff;
begin
  if SignInEnded or ChatOff then Exit;
  if (Room <> '') and not InDm and not OpeningBusy then
    ApiGetAsync('/api/room/members?' + Query(['room', Room]), @StaffDone, RoomGen, 'members');
end;

procedure TMainForm.StaffDone(Job: TApiJob);
begin
  if Job.Tag <> RoomGen then
    Exit;
  Staff.Free;
  Staff := nil;
  if Job.Error = '' then
  try
    Staff := Job.ArrayJSON;
  except
    Staff := nil;
  end;
  if Staff = nil then
    Staff := TJSONArray.Create;
  ShowPeople;
  ShowRooms;
end;

{ The list's width is saved for two columns, whatever it is at the time. }
procedure TMainForm.SavingProps(Sender: TObject);
begin
  if NarrowMode then
  begin
    RoomList.Align := alLeft;
    RoomList.Width := WideListWidth;
  end;
end;

{ Room > Delete this conversation: one's own side of it goes; the other
  member keeps theirs (the server removes a message once both have). }
procedure TMainForm.DeleteDmClick(Sender: TObject);
begin
  if not InDm then
    Exit;
  ActOnRow(Room, raDeleteConversation);
end;

procedure TMainForm.ActSignOutExecute(Sender: TObject);
begin
  if not ActSignOut.Enabled then Exit;
  ActSignOut.Enabled := False;
  ApiPostAsync('/api/signout', [], @SignOutDone);
end;

procedure TMainForm.SignOutDone(Job: TApiJob);
begin
  ActSignOut.Enabled := True;
  Disconnect;
  Token := '';
  if Accounts.IndexOfName(Server) >= 0 then
    Accounts.Delete(Accounts.IndexOfName(Server));
  SaveAccount;
  Application.QueueAsyncCall(@Start, 0);
end;

{ Everything of the account on show put away: for signing out, and for
  going to another server.  The token is left to the caller. }
procedure TMainForm.Disconnect;
var
  I: integer;
begin
  ChatOff := False;
  PollingWorks := False;
  ApiResetSignInFailure;
  NoticeBar.Hide;
  NoticeToast.Hide;
  RetryAttempt := 0;
  RetryStatus := 0;
  OutageSince := 0;
  RetryDue := 0;
  RetryBusy := False;
  SignInEnded := False;
  ThreadPane.AccountReady := True;
  RetrySendRoom := '';
  ConnectionText := '';
  ProbePending := False;
  ReauthPending := False;
  AdminMenu.Visible := False;
  if Oversight <> nil then
    Oversight.Reset;
  if MemberAdmin <> nil then MemberAdmin.Reset;
  if ChannelAdmin <> nil then ChannelAdmin.Reset;
  LiveRetry.Enabled := False;
  StopLive;
  PingTimer.Enabled := False;
  // Answers still on their way were this account's.
  ApiForgetAll;
  Inc(RoomGen);
  Inc(UploadGen);
  Uploading := 0;
  WipeBytes(KeyWrap);
  WipeText(KeyPassword);
  WipeText(KeyAnswer);
  SyncBusy := False;
  SyncAgain := False;
  Sending := False;
  ActSignOut.Enabled := True;
  RowActionBusy := False;
  NoticePending := False;
  NoticeChannel := '';
  FreeAndNil(NoticeBefore);
  RowTarget := '';
  IdleBusy := False;
  DmNewsBusy := False;
  OpeningBusy := False;
  MyName := '';
  WipeBytes(MyKey);
  WipeBytes(DmKey);
  ThreadClosed(nil);
  Shown.Clear;
  DmReload.Clear;
  Previews.Clear;
  Drafts.Clear;
  FreeAndNil(EditPayload);
  WipeText(DraftBeforeEdit);
  WipeText(SentText);
  WipeText(AfterOpen);
  SentRoom := '';
  OpenPub := '';
  OpenKeyName := '';
  for I := 0 to Downloads.Count - 1 do
    with TBytesStream(Downloads.Objects[I]) do
      if Size > 0 then FillChar(Memory^, Size, 0);
  Downloads.Clear;
  DownloadPending.Clear;
  ClearAnswer;
  Commands.Clear;
  SuggestTimer.Enabled := False;
  SuggestQuery := '';
  SuggestNames.Clear;
  Inc(SuggestGen);
  ClearAttached;
  Composer.Clear;
  EditingId := 0;
  Messages.Clear;
  RoomList.Clear;
  Slugs.Clear;
  MemberList.Clear;
  MemberNames.Clear;
  Staff.Clear;
  HereSeen.Clear;
  RoomsSeen.Clear;
  DmsSeen.Clear;
  Pictures.Clear;
  IconIndex.Clear;
  Icons.Clear;
  FreeAndNil(Card);
  FreeAndNil(MyCan);
  Composer.ReadOnly := True;
  ShowRoomMenu;
  CanTalk := False;
  ActSend.Enabled := False;
  AttachButton.Enabled := False;
  PendingTarget := '';
  DmReadDue := False;
  DmCheckDue := False;
  HideSuggest;
  TrayBadge(0);
  RoomHeader.Caption := '';
  Caption := 'Exedra';
end;

{ ---- more than one server ---- }

{ The Servers menu: every server signed in to, the one on show ticked, and
  a way to add one. }
procedure TMainForm.BuildServersMenu;
var
  I: integer;
  Item: TMenuItem;
  Url: string;
begin
  ServersMenu.Clear;
  if (Server <> '') and (Accounts.IndexOfName(Server) < 0) then
    Accounts.Values[Server] := Token;
  for I := 0 to Accounts.Count - 1 do
  begin
    Url := Accounts.Names[I];
    Item := TMenuItem.Create(Self);
    Item.Caption := StringReplace(StringReplace(Url, 'https://', '', []), 'http://', '', []);
    Item.Hint := Url;
    Item.Checked := SameText(Url, Server);
    Item.RadioItem := True;
    Item.OnClick := @ServerPick;
    ServersMenu.Add(Item);
  end;
  if Accounts.Count > 0 then
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := '-';
    ServersMenu.Add(Item);
  end;
  Item := TMenuItem.Create(Self);
  Item.Caption := 'Add a server...';
  Item.OnClick := @AddServerClick;
  ServersMenu.Add(Item);
end;

procedure TMainForm.ServerPick(Sender: TObject);
begin
  SwitchServer(TMenuItem(Sender).Hint, '');
end;

{ Sign in somewhere else; the server left keeps its token for coming back. }
procedure TMainForm.AddServerClick(Sender: TObject);
begin
  if Token <> '' then
    Accounts.Values[Server] := Token;
  if not SignIn(True) then Exit;
  if Started then
    Disconnect;
  Room := '';
  Accounts.Values[Server] := Token;
  SaveAccount;
  BuildServersMenu;
  if Started then
    Application.QueueAsyncCall(@Start, 0);
end;

{ To another server: with the token kept from last time, or the sign-in
  window at Start; Slug is a channel to open there, or ''. }
procedure TMainForm.SwitchServer(const Url, Slug: string);
var
  Want: string;
begin
  Want := ExcludeTrailingPathDelimiter(Trim(Url));
  if Want = '' then
    Exit;
  if SameText(Want, Server) then
  begin
    if (Slug <> '') and Started and (MyName <> '') then
      OpenRoom(Slug);
    Exit;
  end;
  if Token <> '' then
    Accounts.Values[Server] := Token;
  if Started then
    Disconnect;
  Server := Want;
  Token := Accounts.Values[Want];
  Room := Slug;
  SaveAccount;
  BuildServersMenu;
  if Started then
    Application.QueueAsyncCall(@Start, 0);
end;

{ An .exedra file names a server and optional starting channel under
  [exedra], with server= and channel= (docs/API.md). }
procedure TMainForm.OpenConnectionFile(const Path: string);
var
  Url, Slug, Whole, Why: string;
begin
  ReadConnectionFile(Path, Url, Slug);
  if (Url = '') or not (Url.StartsWith('https://') or Url.StartsWith('http://')) then
  begin
    NoticeToast.Show(ExtractFileName(Path) + ' is not an Exedra connection file: it names no server.');
    Exit;
  end;
  if not ServerAddress(Url, Whole, Why) then
  begin
    NoticeToast.Show(ExtractFileName(Path) + ': ' + Why);
    Exit;
  end;
  SwitchServer(Whole, Slug);
end;

procedure TMainForm.WriteConnectionFile(const Path: string);
begin
  if InDm then
    SaveConnectionFile(Path, Server, '')
  else
    SaveConnectionFile(Path, Server, Room);
end;

{ The files this program was started with, or that a later start handed
  over (FileAss keeps one Exedra running and forwards the rest). }
procedure TMainForm.ParametersGiven(Sender: TObject; Parameters: TStrings; const WorkingDirectory: utf8string; Initial: boolean);
var
  P, Path: string;
begin
  if not Initial then
  begin
    Show;
    if WindowState = wsMinimized then
      WindowState := wsNormal;
    Application.BringToFront;
  end;
  for P in Parameters do
  begin
    if not SameText(ExtractFileExt(P), '.exedra') then
      Continue;
    Path := P;
    if not FilenameIsAbsolute(Path) then
      Path := IncludeTrailingPathDelimiter(WorkingDirectory) + Path;
    if FileExists(Path) then
      OpenConnectionFile(Path);
  end;
end;

procedure TMainForm.OpenConnectClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Title := 'Open a connection file';
    D.Filter := 'Exedra connection|*.exedra|All files|*';
    if D.Execute then
      OpenConnectionFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TMainForm.SaveConnectClick(Sender: TObject);
var
  D: TSaveDialog;
  Target: TApiTarget;
  Generation: integer;
begin
  if Server = '' then
    Exit;
  D := TSaveDialog.Create(Self);
  Target := ApiTarget;
  Generation := RoomGen;
  try
    D.Title := 'Save a connection file';
    D.Filter := 'Exedra connection|*.exedra';
    D.DefaultExt := 'exedra';
    D.Options := D.Options + [ofOverwritePrompt];
    D.FileName := StringReplace(StringReplace(Server, 'https://', '', []), 'http://', '', []) + '.exedra';
    if D.Execute and ApiTargetCurrent(Target) and (Generation = RoomGen) then
      WriteConnectionFile(D.FileName);
  finally
    D.Free;
  end;
end;

{ Tell the desktop that .exedra files are this program's (FileAss), or
  take that back. }
procedure TMainForm.AssocClick(Sender: TObject);
var
  R: TFileAssResult;
begin
  R := FileAss.RegisterAll;
  if R.Succeeded then
    NoticeToast.Show('From now on an .exedra file opens in Exedra.')
  else
    NoticeBar.Show(R.Message, mtError, [], 'association');
end;

procedure TMainForm.UnassocClick(Sender: TObject);
var
  R: TFileAssResult;
begin
  R := FileAss.UnregisterAll;
  if R.Succeeded then
    NoticeToast.Show('Exedra no longer opens .exedra files.')
  else
    NoticeBar.Show(R.Message, mtError, [], 'association');
end;

procedure TMainForm.ActQuitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.ActReloadExecute(Sender: TObject);
begin
  if Commands.Count = 0 then
    ApiGetAsync('/api/commands', @CommandsDone);
  OpenRoom(Room);
end;

procedure TMainForm.ActAboutExecute(Sender: TObject);
begin
  ShowAbout(Server);
end;

procedure TMainForm.PingTimerTimer(Sender: TObject);
begin
  if SignInEnded or ChatOff or (ApiRetryDue > GetTickCount64) then Exit;
  // The system went light or dark: the mixed colors follow.
  if (ColorToRGB(clWindow) <> ThemePaper) or (ColorToRGB(clWindowText) <> ThemeInk) then
    Retheme;
  // Away after AutoAway minutes without a key or a click, as on the web page.
  if (AutoAway > 0) and not Idle and not IdleBusy and (GetTickCount64 - LastInput >= QWord(AutoAway) * 60000) then
  begin
    IdleBusy := True;
    ApiPostAsync('/api/prefs', ['idle', '1'], @IdleDone, 1, 'idle');
  end;
  if SignInEnded then Exit;
  // In case a window manager changed the state without saying so.
  TellShown;
  if LiveId <> '' then
  try
    PingLive;
  except
    ConnectionLost(0);
  end
  else if (OutageSince = 0) and not PollingWorks then
    ConnectionLost(0);
  // A catch-up on every tick, live or not: a ring that could not be acted
  // on is not lost, and the server keeps seeing this member here.
  try
    if MyName <> '' then
    begin
      Sync;
      ReadStaff;
      if InDm then
      begin
        if LiveId = '' then
          DmCheckDue := True;
        DmNews;
      end;
    end;
  except
    // The next tick.
  end;
end;

end.
