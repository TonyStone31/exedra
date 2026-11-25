unit SyntaxLangs;

{ Language descriptions for SyntaxTable, plus scanners for Python, XML,
  YAML, diffs and makefiles. Registrations supply code-block language
  aliases; word lists follow each language's reference. }

{$mode objfpc}{$H+}

interface

uses
  Types, SysUtils, syntax.highlighter, SyntaxTable;

type
  TCSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TCppSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TCSharpSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TJavaSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TKotlinSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TSwiftSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TRustSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TZigSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TDSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TTypeScriptSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TRubySyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TLuaSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TPhpSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TPerlSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TBasicSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TTomlSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TAssemblySyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TBatchSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TPowerShellSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TDockerSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TFortranSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TAdaSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TModulaSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TOberonSyntaxHighlighter = class(TTableSyntaxHighlighter)
  protected
    class function Describe: TLanguageDescription; override;
  end;

  TPythonSyntaxHighlighter = class(TByteSyntaxHighlighter)
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

  TXmlSyntaxHighlighter = class(TByteSyntaxHighlighter)
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

  TYamlSyntaxHighlighter = class(TByteSyntaxHighlighter)
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

  TDiffSyntaxHighlighter = class(TByteSyntaxHighlighter)
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

  TMakeSyntaxHighlighter = class(TByteSyntaxHighlighter)
  protected
    class function GetLanguages: TStringDynArray; override;
  public
    procedure DoExecute(const Source: string); override;
  end;

implementation

const
  Letters = ['A'..'Z', 'a'..'z', '_', #128..#255];
  NameChars = Letters + ['0'..'9'];
  CKeywords =
    'alignas alignof auto break case const constexpr continue default do else enum extern for goto if inline register restrict return sizeof static static_assert struct switch thread_local typedef typeof typeof_unqual union volatile while _Alignas _Alignof _Atomic _BitInt _Generic _Noreturn _Static_assert _Thread_local';
  CTypes = 'bool char double float int long short signed unsigned void _Bool _Complex _Decimal32 _Decimal64 _Decimal128 _Imaginary true false nullptr NULL';
  AssemblyWords =
    'adc add adds adcs adr adrp and ands asr b bl blr br bne beq bgt bge blt ble bic call cbnz cbz clc cld cli cmn cmp csel dec div eor fadd fdiv fmul fsub hlt idiv imul inc int ja jae jb jbe je jg jge jl jle jmp jne jnz jz ldp ldr ldrb ldrh lea leave lock lsl lsr mov movabs movk movn movs movsx movsxd movw movz movzx mul neg nop not or orr pop push rep ret rol ror sal sar sbb scasb setz shl shr stp str strb strh sub subs svc syscall sysenter tbz tbnz test ud2 udiv xor';
  AssemblyRegisters =
    'al ah ax eax rax bl bh bx ebx rbx cl ch cx ecx rcx dl dh dx edx rdx si esi rsi di edi rdi sp esp rsp bp ebp rbp ip eip rip r8 r9 r10 r11 r12 r13 r14 r15 r8d r9d r10d r11d r12d r13d r14d r15d cs ds es fs gs ss xmm0 xmm1 xmm2 xmm3 xmm4 xmm5 xmm6 xmm7 ymm0 ymm1 ymm2 ymm3 zmm0 zmm1 zmm2 zmm3 r0 r1 r2 r3 r4 r5 r6 r7 lr pc x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 x29 x30 xzr w0 w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 w11 w12 w13 w14 w15 w16 w17 w18 w19 w20 w21 w22 w23 w24 w25 w26 w27 w28 w29 w30 wzr';

procedure CForms(var Desc: TLanguageDescription);
begin
  LineComment(Desc, '//');
  BlockComment(Desc, '/*', '*/');
  StringForm(Desc, 'u8"', '"');
  StringForm(Desc, 'u"', '"');
  StringForm(Desc, 'U"', '"');
  StringForm(Desc, 'L"', '"');
  StringForm(Desc, 'u8''', '''', '\', False, False, shCharacters);
  StringForm(Desc, 'u''', '''', '\', False, False, shCharacters);
  StringForm(Desc, 'U''', '''', '\', False, False, shCharacters);
  StringForm(Desc, 'L''', '''', '\', False, False, shCharacters);
  StringForm(Desc, '"', '"');
  StringForm(Desc, '''', '''', '\', False, False, shCharacters);
  Desc.Numbers.Hex := True;
  Desc.Numbers.Binary := True;
  Desc.Numbers.LeadingOctal := True;
  Desc.Numbers.HexExponent := True;
  Desc.Numbers.Suffixes := 'uUlLfF';
end;

{ Word lists follow the language references, rather than editor grammars. }
class function TCSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('c', CKeywords, CTypes);
  CForms(Result);
  Result.Directive := '#';
  Result.Numbers.Separators := True;
  Result.Numbers.Separator := '''';
end;

class function TCppSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('cpp c++ cc h hpp',
    'alignas alignof and and_eq asm auto bitand bitor break case catch class co_await co_return co_yield compl concept const consteval constexpr constinit const_cast continue contract_assert decltype default delete do dynamic_cast else enum explicit export extern for friend goto if import inline module mutable namespace new noexcept not not_eq operator or or_eq private protected public register reinterpret_cast requires return sizeof static static_assert static_cast struct switch template this thread_local throw try typedef typeid typename union using virtual volatile while xor xor_eq', CTypes + ' char8_t char16_t char32_t wchar_t');
  CForms(Result);
  Result.Flavor := lfCpp;
  Result.Directive := '#';
  Result.Numbers.Separators := True;
  Result.Numbers.Separator := '''';
end;

class function TCSharpSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('csharp cs c#',
    'abstract as base break case catch checked class const continue default delegate do else enum event explicit extern finally fixed for foreach goto if implicit in interface internal is lock namespace new operator out override params private protected public readonly ref return sealed sizeof stackalloc static struct switch this throw try typeof unchecked unsafe using virtual volatile while', 'bool byte char decimal double float int long object sbyte short string uint ulong ushort void true false null');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/');
  StringForm(Result, '$@"', '"', #0, True, True);
  StringForm(Result, '@$"', '"', #0, True, True);
  StringForm(Result, '@"', '"', #0, True, True);
  StringForm(Result, '$"', '"');
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  Result.Flavor := lfCSharp;
  Result.Directive := '#';
  Result.IdentifierStart := Result.IdentifierStart + ['@'];
  Result.IdentifierRest := Result.IdentifierRest + ['@'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'uUlLfFdDmM';
end;

class function TJavaSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('java',
    'abstract assert break case catch class const continue default do else enum extends final finally for goto if implements import instanceof interface native new package private protected public return static strictfp super switch synchronized this throw throws transient try volatile while', 'boolean byte char double float int long short void true false null');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/');
  StringForm(Result, '"""', '"""', '\', True);
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  Result.Attribute := '@';
  Result.IdentifierStart := Result.IdentifierStart + ['$'];
  Result.IdentifierRest := Result.IdentifierRest + ['$'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.LeadingOctal := True;
  Result.Numbers.HexExponent := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'lLfFdD';
end;

class function TKotlinSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('kotlin kt', 'as break class continue do else for fun if in interface is object package return super this throw try typealias typeof val var when while',
    'Any Boolean Byte Char Double Float Int Long Nothing Short String Unit true false null');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/', True);
  StringForm(Result, '"""', '"""', #0, True);
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  StringForm(Result, '`', '`', #0);
  Result.Attribute := '@';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'uUlLfF';
end;

class function TSwiftSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('swift',
    'associatedtype borrowing break case catch class consuming continue default defer deinit do else enum extension fallthrough fileprivate for func guard if import in init inout internal is let nonisolated open operator precedencegroup private protocol public repeat rethrows return some static struct subscript super switch throws throw try typealias var where while as await async actor', 'Any Bool Character Double Float Int Int8 Int16 Int32 Int64 Never Self String UInt UInt8 UInt16 UInt32 UInt64 Void true false nil');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/', True);
  StringForm(Result, '"""', '"""', '\', True);
  StringForm(Result, '"', '"');
  StringForm(Result, '`', '`', #0);
  Result.Attribute := '@';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.HexExponent := True;
  Result.Numbers.Separators := True;
end;

class function TRustSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('rust rs',
    'as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait type unsafe use where while abstract become box do final gen macro override priv try typeof unsized virtual yield', 'bool char str i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 true false');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/', True);
  StringForm(Result, 'b"', '"');
  StringForm(Result, 'c"', '"');
  StringForm(Result, '"', '"', '\', True);
  StringForm(Result, 'b''', '''', '\', False, False, shCharacters);
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  Result.Flavor := lfRust;
  Result.Attribute := '#';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'uifsize0123456789';
end;

class function TZigSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('zig',
    'addrspace align allowzero and anyframe anytype asm async await break callconv catch comptime const continue defer else enum errdefer error export extern fn for if inline linksection noalias noinline nosuspend opaque or orelse packed pub resume return section struct suspend switch test threadlocal try union unreachable usingnamespace var volatile while', 'anyerror bool c_char c_int c_long c_longdouble c_longlong c_short c_uint c_ulong c_ulonglong c_ushort comptime_float comptime_int f16 f32 f64 f80 f128 i8 i16 i32 i64 i128 isize noreturn type u8 u16 u32 u64 u128 usize void true false null undefined');
  LineComment(Result, '//');
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  StringForm(Result, '@"', '"');
  Result.Flavor := lfZig;
  Result.Attribute := '@';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.HexExponent := True;
  Result.Numbers.Separators := True;
end;

class function TDSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('d',
    'abstract alias align asm assert auto body break case cast catch class const continue debug default delegate delete deprecated do else enum export extern final finally for foreach foreach_reverse function goto if immutable import in inout interface invariant is lazy mixin module new nothrow out override package pragma private protected public pure ref return scope shared static struct super switch synchronized template this throw try typeid typeof union unittest version while with __gshared __traits __vector __parameters', 'bool byte cdouble cent cfloat char creal dchar double float idouble ifloat int ireal long real short ubyte ucent uint ulong ushort void wchar true false null');
  LineComment(Result, '//');
  BlockComment(Result, '/+', '+/', True);
  BlockComment(Result, '/*', '*/');
  StringForm(Result, 'r"', '"', #0, True, False, shRawString);
  StringForm(Result, '`', '`', #0, True, False, shRawString);
  StringForm(Result, 'x"', '"', #0, True);
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', '\', False, False, shCharacters);
  Result.Attribute := '@';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.HexExponent := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'uULfi';
end;

class function TTypeScriptSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('typescript ts tsx',
    'abstract as async await break case catch class const constructor continue debugger declare default delete do else enum export extends finally for from function get if implements import in infer instanceof interface is keyof let module namespace new of override package private protected public readonly require return satisfies set static super switch this throw try type typeof using var void while with yield', 'any bigint boolean never number object string symbol unknown true false null undefined');
  LineComment(Result, '//');
  BlockComment(Result, '/*', '*/');
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''');
  StringForm(Result, '`', '`', '\', True, False, shTemplate);
  Result.Attribute := '@';
  Result.IdentifierStart := Result.IdentifierStart + ['$'];
  Result.IdentifierRest := Result.IdentifierRest + ['$'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'n';
end;

class function TRubySyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('ruby rb',
    'BEGIN END alias and begin break case class def defined? do else elsif end ensure for if in module next not or redo rescue retry return self super then undef unless until when while yield __FILE__ __LINE__ __ENCODING__',
    'true false nil');
  BlockComment(Result, '=begin', '=end');
  LineComment(Result, '#');
  StringForm(Result, '"', '"', '\', True);
  StringForm(Result, '''', '''', '\', True);
  StringForm(Result, '`', '`', '\', True);
  Result.Flavor := lfRuby;
  Result.IdentifierRest := Result.IdentifierRest + ['?', '!'];
  Result.IdentifierStart := Result.IdentifierStart + ['@', '$'];
  Result.IdentifierRest := Result.IdentifierRest + ['@', '$'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.Separators := True;
  Result.Numbers.Suffixes := 'ri';
end;

class function TLuaSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('lua', 'and break do else elseif end for function goto if in local not or repeat return then until while', 'true false nil');
  LineComment(Result, '--');
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''');
  Result.Flavor := lfLua;
  Result.Numbers.Hex := True;
  Result.Numbers.HexExponent := True;
end;

class function TPhpSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('php',
    'abstract and array as break callable case catch class clone const continue declare default die do echo else elseif empty enddeclare endfor endforeach endif endswitch endwhile enum eval exit extends final finally fn for foreach function global goto if implements include include_once instanceof insteadof interface isset list match namespace new or print private protected public readonly require require_once return static switch throw trait try unset use var while xor yield', 'bool float int iterable mixed never object string void false true null');
  Result.CaseSensitive := False;
  LineComment(Result, '//');
  LineComment(Result, '#');
  BlockComment(Result, '/*', '*/');
  StringForm(Result, '"', '"', '\', True);
  StringForm(Result, '''', '''', '\', True);
  StringForm(Result, '`', '`', '\', True);
  Result.Flavor := lfPhp;
  Result.Attribute := '#[';
  Result.IdentifierStart := Result.IdentifierStart + ['$'];
  Result.IdentifierRest := Result.IdentifierRest + ['$'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.LeadingOctal := True;
  Result.Numbers.Separators := True;
end;

class function TPerlSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('perl pl',
    'BEGIN CHECK END INIT UNITCHECK and bless break caller continue default die do dump else elsif eval exit for foreach format given goto if last local my next no not or our package print redo require return say state sub unless until use when while xor', 'undef __FILE__ __LINE__ __PACKAGE__');
  LineComment(Result, '#');
  StringForm(Result, '"', '"', '\', True);
  StringForm(Result, '''', '''', '\', True);
  StringForm(Result, '`', '`', '\', True);
  Result.Flavor := lfPerl;
  Result.IdentifierStart := Result.IdentifierStart + ['$', '@', '%'];
  Result.IdentifierRest := Result.IdentifierRest + ['$', '@', '%'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.LeadingOctal := True;
  Result.Numbers.Separators := True;
end;

class function TBasicSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('basic vb freebasic',
    'addhandler addressof alias and andalso as asm byref byval call case catch class common const constructor continue declare delegate delete dim do each else elseif end enum erase error event exit extern finally for friend function get global gosub goto handles if implements imports in inherits input interface is let lib loop me mod module namespace new next not on operator option or orelse overloads overrides preserve print private property protected public raiseevent read redim rem removehandler restore resume return select set shared static step stop sub synclock then throw to try type typeof union using virtual wend while with withevents write xor', 'boolean byte char currency date decimal double integer long longint longptr object sbyte short single string ubyte uinteger ulong ulongint ushort variant void true false nothing');
  Result.CaseSensitive := False;
  Result.Flavor := lfBasic;
  BlockComment(Result, '/''', '''/', True);
  LineComment(Result, '''');
  LineComment(Result, 'rem', False, True);
  StringForm(Result, '!"', '"');
  StringForm(Result, '"', '"', #0, False, True);
  Result.Directive := '#';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.Suffixes := 'uUlLfFdD%!#&';
end;

class function TTomlSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('toml', '', 'true false inf nan');
  Result.Flavor := lfToml;
  LineComment(Result, '#');
  StringForm(Result, '"""', '"""', '\', True);
  StringForm(Result, '''''''', '''''''', #0, True, False, shRawString);
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', #0, False, False, shRawString);
  Result.IdentifierRest := Result.IdentifierRest + ['-'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.Separators := True;
end;

class function TAssemblySyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('asm nasm gas x86 arm', AssemblyWords, AssemblyRegisters + ' byte word dword qword oword tword ptr rel abs near far short');
  Result.Flavor := lfAssembly;
  Result.CaseSensitive := False;
  LineComment(Result, ';');
  LineComment(Result, '//');
  // A hash followed by a number is an ARM immediate, not a comment.
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''');
  Result.IdentifierStart := Result.IdentifierStart + ['.', '$'];
  Result.IdentifierRest := Result.IdentifierRest + ['.', '$'];
  Result.Directive := '%';
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Octal := True;
  Result.Numbers.TrailingBase := True;
end;

class function TBatchSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('batch bat cmd',
    'assoc break call cd chdir cls color copy date del dir do echo else endlocal erase exit for ftype goto if in md mkdir move path pause popd prompt pushd rd rem ren rename rmdir set setlocal shift start time title type ver verify vol', 'errorlevel exist defined');
  Result.CaseSensitive := False;
  Result.Flavor := lfBatch;
  LineComment(Result, 'rem', True, True);
  LineComment(Result, '::', True);
  StringForm(Result, '"', '"', '^');
  Result.Numbers.Hex := True;
end;

class function TPowerShellSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('powershell ps1',
    'begin break catch class clean continue data define do dynamicparam else elseif end enum exit filter finally for foreach from function hidden if in inlinescript parallel param process return sequence static switch throw trap try until using var while workflow', '$true $false $null');
  Result.CaseSensitive := False;
  Result.Flavor := lfPowerShell;
  BlockComment(Result, '<#', '#>');
  LineComment(Result, '#');
  StringForm(Result, '"', '"', '`', True, True);
  StringForm(Result, '''', '''', #0, True, True);
  Result.IdentifierStart := Result.IdentifierStart + ['$'];
  Result.IdentifierRest := Result.IdentifierRest + ['$', '-', ':'];
  Result.Numbers.Hex := True;
  Result.Numbers.Binary := True;
  Result.Numbers.Suffixes := 'uUlLdDnNkbmgtpKBMGTP';
end;

class function TDockerSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('dockerfile', 'add arg cmd copy entrypoint env expose from healthcheck label maintainer onbuild run shell stopsignal user volume workdir', '');
  Result.CaseSensitive := False;
  Result.Flavor := lfDocker;
  LineComment(Result, '#', True);
  StringForm(Result, '"', '"');
  StringForm(Result, '''', '''', #0);
  Result.Numbers.Exponent := False;
end;

class function TFortranSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('fortran',
    'abstract allocatable allocate assignment associate asynchronous backspace bind block call case class close codimension common contains contiguous continue critical cycle data deallocate deferred dimension do elemental else elseif elsewhere end enddo endif entry enum enumerator equivalence error exit extends external final flush forall format function generic goto if implicit import in include inout intent interface intrinsic module namelist non_overridable nopass nullify only open operator optional out parameter pass pause pointer print private procedure program protected public pure read recursive result return rewind save select sequence stop submodule subroutine sync target then type use value volatile wait where while write', 'character complex double integer logical precision real true false');
  Result.CaseSensitive := False;
  Result.Flavor := lfFortran;
  LineComment(Result, '!');
  StringForm(Result, '"', '"', #0, False, True);
  StringForm(Result, '''', '''', #0, False, True);
  Result.Numbers.ExponentLetters := 'eEdDqQ';
  Result.Numbers.Suffixes := '_0123456789';
end;

class function TAdaSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('ada',
    'abort abs abstract accept access aliased all and array at begin body case constant declare delay delta digits do else elsif end entry exception exit for function generic goto if in interface is limited loop mod new not null of or others out overriding package parallel pragma private procedure protected raise range record rem renames requeue return reverse select separate some subtype synchronized tagged task terminate then type until use when while with xor', 'boolean character duration float integer natural positive string wide_character wide_string true false');
  Result.CaseSensitive := False;
  Result.Flavor := lfAda;
  LineComment(Result, '--');
  StringForm(Result, '"', '"', #0, False, True);
  StringForm(Result, '''', '''', #0, False, False, shCharacters);
  Result.Numbers.Based := True;
  Result.Numbers.Separators := True;
end;

class function TModulaSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('modula-2 modula2',
    'AND ARRAY BEGIN BY CASE CONST DEFINITION DIV DO ELSE ELSIF END EXCEPT EXIT EXPORT FINALLY FOR FORWARD FROM IF IMPLEMENTATION IMPORT IN LOOP MOD MODULE NOT OF OR PACKEDSET POINTER PROCEDURE QUALIFIED RECORD REM REPEAT RETRY RETURN SET THEN TO TYPE UNTIL VAR WHILE WITH', 'BITSET BOOLEAN CARDINAL CHAR COMPLEX INTEGER LONGCARD LONGCOMPLEX LONGINT LONGREAL PROC REAL SHORTCARD SHORTINT TRUE FALSE NIL');
  BlockComment(Result, '(*', '*)', True);
  StringForm(Result, '"', '"', #0);
  StringForm(Result, '''', '''', #0);
  Result.Numbers.ExponentLetters := 'eED';
  Result.Numbers.TrailingBase := True;
end;

class function TOberonSyntaxHighlighter.Describe: TLanguageDescription;
begin
  Result := Language('oberon',
    'ARRAY BEGIN BY CASE CONST DIV DO ELSE ELSIF END EXIT FOR IF IMPORT IN IS LOOP MOD MODULE OF OR POINTER PROCEDURE RECORD REPEAT RETURN THEN TO TYPE UNTIL VAR WHILE WITH',
    'BOOLEAN BYTE CHAR INTEGER LONGINT LONGREAL REAL SET SHORTINT TRUE FALSE NIL');
  BlockComment(Result, '(*', '*)', True);
  StringForm(Result, '"', '"', #0);
  StringForm(Result, '''', '''', #0);
  Result.Numbers.ExponentLetters := 'eED';
  Result.Numbers.TrailingBase := True;
end;

class function TPythonSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['python', 'py'];
end;

procedure TPythonSyntaxHighlighter.DoExecute(const Source: string);
var
  First, P, PrefixLength: SizeInt;
  Quote, Escape: char;
  Delimiter, Value: string;
  Kind: TSyntaxHighlightKind;
  LineStart: boolean;
begin
  Start(Source);
  LineStart := True;
  while Cursor <= Limit do
  begin
    First := Cursor;
    Kind := shDefault;
    P := Cursor;
    while (P <= Limit) and (P - Cursor < 2) and (Text[P] in ['r', 'R', 'b', 'B', 'u', 'U', 'f', 'F', 't', 'T']) do Inc(P);
    PrefixLength := P - Cursor;
    if Ch in ['"', ''''] then
    begin
      P := Cursor;
      PrefixLength := 0;
    end;
    if (P <= Limit) and (Text[P] in ['"', '''']) then
    begin
      Escape := '\';
      Quote := Text[P];
      Delimiter := Quote;
      if (P + 2 <= Limit) and (Text[P + 1] = Quote) and (Text[P + 2] = Quote) then
        Delimiter := Quote + Quote + Quote;
      Cursor := P;
      Quoted(Delimiter, Delimiter, Escape, Length(Delimiter) = 3, False);
      // Raw prefixes affect value decoding, but backslashes still shield quotes.
      Kind := shStrings;
      if (PrefixLength > 0) and (Pos('r', LowerCase(Copy(Text, First, PrefixLength))) > 0) then Kind := shRawString;
    end
    else if Ch = '#' then
    begin
      LineEnd;
      Kind := shComment;
    end
    else if LineStart and (Ch = '@') and (Ch(1) in Letters) then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameChars + ['.']) do Inc(Cursor);
      Kind := shAttribute;
    end
    else if Ch in Letters then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameChars) do Inc(Cursor);
      Value := Copy(Text, First, Cursor - First);
      if WordsContain('and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield',
        Value) then
        Kind := shKeyword
      else if WordsContain('True False None Ellipsis NotImplemented bool bytes bytearray complex dict float frozenset int list memoryview object range set slice str tuple type',
        Value) then Kind := shKey;
    end
    else if (Ch in ['0'..'9']) or ((Ch = '.') and (Ch(1) in ['0'..'9'])) then
    begin
      if At('0x') or At('0X') or At('0b') or At('0B') or At('0o') or At('0O') then
      begin
        Inc(Cursor, 2);
        while (Cursor <= Limit) and (Ch in ['0'..'9', 'a'..'f', 'A'..'F', '_']) do Inc(Cursor);
      end
      else
      begin
        while (Cursor <= Limit) and (Ch in ['0'..'9', '_']) do Inc(Cursor);
        if (Ch = '.') and (Ch(1) <> '.') then
        begin
          Inc(Cursor);
          while (Cursor <= Limit) and (Ch in ['0'..'9', '_']) do Inc(Cursor);
        end;
        if Ch in ['e', 'E'] then
        begin
          Inc(Cursor);
          if Ch in ['+', '-'] then Inc(Cursor);
          while (Cursor <= Limit) and (Ch in ['0'..'9', '_']) do Inc(Cursor);
        end;
      end;
      if Ch in ['j', 'J'] then Inc(Cursor);
      Kind := shNumbers;
    end
    else if Ch in [' ', #9, #10, #13] then
    begin
      while (Cursor <= Limit) and (Ch in [' ', #9, #10, #13]) do
      begin
        if Ch in [#10, #13] then LineStart := True;
        Inc(Cursor);
      end;
      Emit(First, Kind);
      Continue;
    end
    else
    begin
      if Ch in ['+', '-', '*', '/', '%', '=', '<', '>', '!', '&', '|', '^', '~', '@'] then Kind := shOperator
      else if Ch in ['(', ')', '[', ']', '{', '}', '.', ',', ':', ';'] then Kind := shSymbol;
      Unknown;
    end;
    Emit(First, Kind);
    LineStart := False;
  end;
  Finish;
end;

class function TXmlSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['xml', 'svg', 'xsd', 'lpi', 'lpk', 'lps'];
end;

procedure TXmlSyntaxHighlighter.DoExecute(const Source: string);
var
  First, Brackets: SizeInt;
  InTag, TagName: boolean;
  Quote: char;
  Kind: TSyntaxHighlightKind;
begin
  Start(Source);
  InTag := False;
  TagName := False;
  while Cursor <= Limit do
  begin
    First := Cursor;
    Kind := shDefault;
    if At('<!--') then
    begin
      Block('<!--', '-->', False);
      Kind := shComment;
    end
    else if At('<![CDATA[') then
    begin
      Quoted('<![CDATA[', ']]>', #0, True, False);
      Kind := shRawString;
    end
    else if At('<?') then
    begin
      Quoted('<?', '?>', #0, True, False);
      Kind := shDirective;
    end
    else if At('<!') then
    begin
      Inc(Cursor, 2);
      Brackets := 0;
      while Cursor <= Limit do
      begin
        if Ch in ['"', ''''] then
        begin
          Quote := Ch;
          Quoted(Quote, Quote, #0, True, False);
        end
        else if At('<!--') then Block('<!--', '-->', False)
        else
        begin
          if Ch = '[' then Inc(Brackets);
          if (Ch = ']') and (Brackets > 0) then Dec(Brackets);
          if (Ch = '>') and (Brackets = 0) then
          begin
            Inc(Cursor);
            Break;
          end;
          Inc(Cursor);
        end;
      end;
      Kind := shDirective;
    end
    else if Ch = '<' then
    begin
      Inc(Cursor);
      if Ch = '/' then Inc(Cursor);
      InTag := True;
      TagName := True;
      Kind := shSymbol;
    end
    else if InTag and (Ch in ['"', '''']) then
    begin
      Quote := Ch;
      Quoted(Quote, Quote, #0, True, False);
      Kind := shStrings;
    end
    else if Ch = '&' then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameChars + ['#', 'x', '-', '.']) do Inc(Cursor);
      if Ch = ';' then Inc(Cursor);
      Kind := shEscape;
    end
    else if InTag and (Ch in Letters + [':']) then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameChars + [':', '-', '.']) do Inc(Cursor);
      if TagName then Kind := shKeyword
      else
        Kind := shAttribute;
      TagName := False;
    end
    else if InTag and (Ch in ['/', '>', '=']) then
    begin
      if Ch = '>' then InTag := False;
      Inc(Cursor);
      Kind := shSymbol;
    end
    else if InTag then
    begin
      if Ch in [' ', #9, #10, #13] then White
      else
        Unknown;
    end
    else
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and not (Ch in ['<', '&']) do Inc(Cursor);
    end;
    Emit(First, Kind);
  end;
  Finish;
end;

class function TYamlSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['yaml', 'yml'];
end;

procedure TYamlSyntaxHighlighter.DoExecute(const Source: string);
var
  First, P, Indent, BlockIndent, CurrentIndent: SizeInt;
  Value: string;
  Quote: char;
  Kind: TSyntaxHighlightKind;
  AtLineStart, BlockActive, InBlock: boolean;
begin
  Start(Source);
  AtLineStart := True;
  BlockActive := False;
  BlockIndent := 0;
  Indent := 0;
  while Cursor <= Limit do
  begin
    First := Cursor;
    Kind := shDefault;
    if AtLineStart then
    begin
      P := Cursor;
      while (P <= Limit) and (Text[P] = ' ') do Inc(P);
      CurrentIndent := P - Cursor;
      InBlock := BlockActive and ((P > Limit) or (Text[P] in [#10, #13]) or (CurrentIndent > BlockIndent));
      if InBlock then
      begin
        LineEnd;
        if Ch = #13 then Inc(Cursor);
        if Ch = #10 then Inc(Cursor);
        Emit(First, shStrings);
        Continue;
      end;
      BlockActive := False;
      Indent := CurrentIndent;
      AtLineStart := False;
    end;
    if Ch in [#10, #13] then
    begin
      if At(#13#10) then Inc(Cursor, 2)
      else
        Inc(Cursor);
      AtLineStart := True;
    end
    else if Ch in [' ', #9] then
      while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor)
    else if (Ch = '#') and ((Cursor = 1) or (Ch(-1) in [' ', #9, #10, #13])) then
    begin
      LineEnd;
      Kind := shComment;
    end
    else if Ch in ['"', ''''] then
    begin
      Quote := Ch;
      if Quote = '"' then Quoted(Quote, Quote, '\', True, False)
      else
        Quoted(Quote, Quote, #0, True, True);
      Kind := shStrings;
    end
    else if Ch in ['|', '>'] then
    begin
      LineEnd;
      Kind := shSymbol;
      BlockActive := True;
      BlockIndent := Indent;
    end
    else if Ch in ['&', '*', '!'] then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and not (Ch in [' ', #9, #10, #13, ',', '[', ']', '{', '}']) do Inc(Cursor);
      Kind := shAttribute;
    end
    else if Ch in [':', ',', '[', ']', '{', '}', '?'] then
    begin
      Inc(Cursor);
      Kind := shSymbol;
    end
    else if (At('---') or At('...')) and (Ch(3) in [' ', #9, #10, #13, #0]) then
    begin
      Inc(Cursor, 3);
      Kind := shDirective;
    end
    else if Ch = '%' then
    begin
      LineEnd;
      Kind := shDirective;
    end
    else if (Ch = '-') and (Ch(1) in [' ', #9, #10, #13]) then
    begin
      Inc(Cursor);
      Kind := shSymbol;
    end
    else
    begin
      Inc(Cursor);
      while Cursor <= Limit do
      begin
        if Ch in [#10, #13, ',', '[', ']', '{', '}'] then Break;
        if (Ch = ':') and (Ch(1) in [' ', #9, #10, #13, #0]) then Break;
        if (Ch = '#') and (Ch(-1) in [' ', #9]) then Break;
        Inc(Cursor);
      end;
      Value := Trim(Copy(Text, First, Cursor - First));
      if Ch = ':' then Kind := shKey
      else if WordsContain('true false True False TRUE FALSE null Null NULL ~', Value) then Kind := shKey
      else if (Value <> '') and (Value[1] in ['0'..'9', '+', '-']) then Kind := shNumbers
      else
        Kind := shStrings;
    end;
    Emit(First, Kind);
  end;
  Finish;
end;

class function TDiffSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['diff', 'patch'];
end;

procedure TDiffSyntaxHighlighter.DoExecute(const Source: string);
var
  First: SizeInt;
  Kind: TSyntaxHighlightKind;
begin
  Start(Source);
  while Cursor <= Limit do
  begin
    First := Cursor;
    Kind := shDefault;
    if At('+++') or At('---') or At('***') or At('diff ') or At('index ') then Kind := shDirective
    else if At('@@') then Kind := shSection
    else if Ch = '+' then Kind := shStrings
    else if Ch = '-' then Kind := shError
    else if Ch = '!' then Kind := shWarning
    else if Ch = '\' then Kind := shComment;
    LineEnd;
    if Ch = #13 then Inc(Cursor);
    if Ch = #10 then Inc(Cursor);
    Emit(First, Kind);
  end;
  Finish;
end;

class function TMakeSyntaxHighlighter.GetLanguages: TStringDynArray;
begin
  Result := ['makefile', 'make'];
end;

procedure TMakeSyntaxHighlighter.DoExecute(const Source: string);
var
  First, P: SizeInt;
  Stack: array of char;
  Depth: SizeInt;
  Value: string;
  Kind: TSyntaxHighlightKind;
  LineStart, Recipe, Target: boolean;
begin
  Start(Source);
  LineStart := True;
  Recipe := False;
  Target := True;
  Stack := nil;
  while Cursor <= Limit do
  begin
    First := Cursor;
    Kind := shDefault;
    if LineStart then
    begin
      Recipe := Ch = #9;
      LineStart := False;
      Target := not Recipe;
    end;
    if Ch in [#10, #13] then
    begin
      if At(#13#10) then Inc(Cursor, 2)
      else
        Inc(Cursor);
      LineStart := Ch(-(Cursor - First) - 1) <> '\';
    end
    else if At('$(') or At('${') then
    begin
      Depth := 1;
      SetLength(Stack, 16);
      if Ch(1) = '(' then Stack[0] := ')'
      else
        Stack[0] := '}';
      Inc(Cursor, 2);
      while (Cursor <= Limit) and (Depth > 0) do
      begin
        if At('$(') or At('${') then
        begin
          if Depth = Length(Stack) then SetLength(Stack, Depth * 2);
          if Ch(1) = '(' then Stack[Depth] := ')'
          else
            Stack[Depth] := '}';
          Inc(Depth);
          Inc(Cursor, 2);
        end
        else if Ch in ['(', '{'] then
        begin
          if Depth = Length(Stack) then SetLength(Stack, Depth * 2);
          if Ch = '(' then Stack[Depth] := ')'
          else
            Stack[Depth] := '}';
          Inc(Depth);
          Inc(Cursor);
        end
        else if Ch = Stack[Depth - 1] then
        begin
          Dec(Depth);
          Inc(Cursor);
        end
        else
          Inc(Cursor);
      end;
      Kind := shInterpolation;
    end
    else if Ch = '$' then
    begin
      Inc(Cursor);
      if Cursor <= Limit then Unknown;
      Kind := shInterpolation;
    end
    else if (Ch = '#') and not Recipe then
    begin
      LineEnd;
      Kind := shComment;
    end
    else if At('\#') or At('\$') or At('\\') then Inc(Cursor, 2)
    else if Ch in ['=', ':', '?', '+', '!'] then
    begin
      Inc(Cursor);
      if Ch = ':' then Inc(Cursor);
      if Ch = '=' then Inc(Cursor);
      Target := False;
      Kind := shOperator;
    end
    else if Ch in Letters + ['.', '%', '-', '/'] then
    begin
      Inc(Cursor);
      while (Cursor <= Limit) and (Ch in NameChars + ['.', '%', '-', '/']) do Inc(Cursor);
      Value := Copy(Text, First, Cursor - First);
      if not Recipe then
      begin
        if WordsContain('define endef undefine ifdef ifndef ifeq ifneq else endif include -include sinclude override export unexport private vpath', Value) then Kind := shKeyword
        else
        begin
          P := Cursor;
          while (P <= Limit) and (Text[P] in [' ', #9]) do Inc(P);
          if (P <= Limit) and (Text[P] in ['=', '?', '+', '!']) then Kind := shKey
          else if Target then Kind := shAttribute;
        end;
      end;
    end
    else if Ch in [' ', #9] then
      while (Cursor <= Limit) and (Ch in [' ', #9]) do Inc(Cursor)
    else
      Unknown;
    Emit(First, Kind);
  end;
  Finish;
end;

initialization
  TCSyntaxHighlighter.Register;
  TCppSyntaxHighlighter.Register;
  TCSharpSyntaxHighlighter.Register;
  TJavaSyntaxHighlighter.Register;
  TKotlinSyntaxHighlighter.Register;
  TSwiftSyntaxHighlighter.Register;
  TRustSyntaxHighlighter.Register;
  TZigSyntaxHighlighter.Register;
  TDSyntaxHighlighter.Register;
  TTypeScriptSyntaxHighlighter.Register;
  TRubySyntaxHighlighter.Register;
  TLuaSyntaxHighlighter.Register;
  TPhpSyntaxHighlighter.Register;
  TPerlSyntaxHighlighter.Register;
  TBasicSyntaxHighlighter.Register;
  TTomlSyntaxHighlighter.Register;
  TAssemblySyntaxHighlighter.Register;
  TBatchSyntaxHighlighter.Register;
  TPowerShellSyntaxHighlighter.Register;
  TDockerSyntaxHighlighter.Register;
  TFortranSyntaxHighlighter.Register;
  TAdaSyntaxHighlighter.Register;
  TModulaSyntaxHighlighter.Register;
  TOberonSyntaxHighlighter.Register;
  TPythonSyntaxHighlighter.Register;
  TXmlSyntaxHighlighter.Register;
  TYamlSyntaxHighlighter.Register;
  TDiffSyntaxHighlighter.Register;
  TMakeSyntaxHighlighter.Register;
end.
