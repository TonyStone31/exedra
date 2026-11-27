// Generated from english.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit EnglishStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TEnglishStemmer = Class(TSnowballProgram)
    private
        a_0 : Array Of TAmong;
        a_1 : Array Of TAmong;
        a_2 : Array Of TAmong;
        a_3 : Array Of TAmong;
        a_4 : Array Of TAmong;
        a_5 : Array Of TAmong;
        a_6 : Array Of TAmong;
        a_7 : Array Of TAmong;
        a_8 : Array Of TAmong;
        a_9 : Array Of TAmong;
        a_10 : Array Of TAmong;
        a_11 : Array Of TAmong;
    public
        Constructor Create;
        Function stem : Boolean; Override;
    private
        Function r_shortv : Boolean;
End;

Implementation

Const
    g_aeo : Array [0..1] Of Char = (
        Chr(17),
        Chr(64)
    );

Const
    g_v : Array [0..3] Of Char = (
        Chr(17),
        Chr(65),
        Chr(16),
        Chr(1)
    );

Const
    g_v_WXY : Array [0..4] Of Char = (
        Chr(1),
        Chr(17),
        Chr(65),
        Chr(208),
        Chr(1)
    );

Const
    g_valid_LI : Array [0..2] Of Char = (
        Chr(55),
        Chr(141),
        Chr(2)
    );

Constructor TEnglishStemmer.Create;
Begin
    SetLength(a_0, 9);
        a_0[0].Str  := 'arsen';
        a_0[0].Index := -1;
        a_0[0].Result := -1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'commun';
        a_0[1].Index := -1;
        a_0[1].Result := -1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'emerg';
        a_0[2].Index := -1;
        a_0[2].Result := -1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'gener';
        a_0[3].Index := -1;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'inter';
        a_0[4].Index := -1;
        a_0[4].Result := -1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'later';
        a_0[5].Index := -1;
        a_0[5].Result := -1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'organ';
        a_0[6].Index := -1;
        a_0[6].Result := -1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'past';
        a_0[7].Index := -1;
        a_0[7].Result := -1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'univers';
        a_0[8].Index := -1;
        a_0[8].Result := -1;
        a_0[8].Method := nil;

    SetLength(a_1, 3);
        a_1[0].Str  := '''';
        a_1[0].Index := -1;
        a_1[0].Result := 1;
        a_1[0].Method := nil;

        a_1[1].Str  := '''s''';
        a_1[1].Index := 0;
        a_1[1].Result := 1;
        a_1[1].Method := nil;

        a_1[2].Str  := '''s';
        a_1[2].Index := -1;
        a_1[2].Result := 1;
        a_1[2].Method := nil;

    SetLength(a_2, 6);
        a_2[0].Str  := 'ied';
        a_2[0].Index := -1;
        a_2[0].Result := 2;
        a_2[0].Method := nil;

        a_2[1].Str  := 's';
        a_2[1].Index := -1;
        a_2[1].Result := 3;
        a_2[1].Method := nil;

        a_2[2].Str  := 'ies';
        a_2[2].Index := 1;
        a_2[2].Result := 2;
        a_2[2].Method := nil;

        a_2[3].Str  := 'sses';
        a_2[3].Index := 1;
        a_2[3].Result := 1;
        a_2[3].Method := nil;

        a_2[4].Str  := 'ss';
        a_2[4].Index := 1;
        a_2[4].Result := -1;
        a_2[4].Method := nil;

        a_2[5].Str  := 'us';
        a_2[5].Index := 1;
        a_2[5].Result := -1;
        a_2[5].Method := nil;

    SetLength(a_3, 3);
        a_3[0].Str  := 'succ';
        a_3[0].Index := -1;
        a_3[0].Result := 1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'proc';
        a_3[1].Index := -1;
        a_3[1].Result := 1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'exc';
        a_3[2].Index := -1;
        a_3[2].Result := 1;
        a_3[2].Method := nil;

    SetLength(a_4, 7);
        a_4[0].Str  := 'even';
        a_4[0].Index := -1;
        a_4[0].Result := 2;
        a_4[0].Method := nil;

        a_4[1].Str  := 'cann';
        a_4[1].Index := -1;
        a_4[1].Result := 2;
        a_4[1].Method := nil;

        a_4[2].Str  := 'inn';
        a_4[2].Index := -1;
        a_4[2].Result := 2;
        a_4[2].Method := nil;

        a_4[3].Str  := 'earr';
        a_4[3].Index := -1;
        a_4[3].Result := 2;
        a_4[3].Method := nil;

        a_4[4].Str  := 'herr';
        a_4[4].Index := -1;
        a_4[4].Result := 2;
        a_4[4].Method := nil;

        a_4[5].Str  := 'out';
        a_4[5].Index := -1;
        a_4[5].Result := 2;
        a_4[5].Method := nil;

        a_4[6].Str  := 'y';
        a_4[6].Index := -1;
        a_4[6].Result := 1;
        a_4[6].Method := nil;

    SetLength(a_5, 7);
        a_5[0].Str  := '';
        a_5[0].Index := -1;
        a_5[0].Result := -1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'ed';
        a_5[1].Index := 0;
        a_5[1].Result := 2;
        a_5[1].Method := nil;

        a_5[2].Str  := 'eed';
        a_5[2].Index := 1;
        a_5[2].Result := 1;
        a_5[2].Method := nil;

        a_5[3].Str  := 'ing';
        a_5[3].Index := 0;
        a_5[3].Result := 3;
        a_5[3].Method := nil;

        a_5[4].Str  := 'edly';
        a_5[4].Index := 0;
        a_5[4].Result := 2;
        a_5[4].Method := nil;

        a_5[5].Str  := 'eedly';
        a_5[5].Index := 4;
        a_5[5].Result := 1;
        a_5[5].Method := nil;

        a_5[6].Str  := 'ingly';
        a_5[6].Index := 0;
        a_5[6].Result := 2;
        a_5[6].Method := nil;

    SetLength(a_6, 13);
        a_6[0].Str  := '';
        a_6[0].Index := -1;
        a_6[0].Result := 3;
        a_6[0].Method := nil;

        a_6[1].Str  := 'bb';
        a_6[1].Index := 0;
        a_6[1].Result := 2;
        a_6[1].Method := nil;

        a_6[2].Str  := 'dd';
        a_6[2].Index := 0;
        a_6[2].Result := 2;
        a_6[2].Method := nil;

        a_6[3].Str  := 'ff';
        a_6[3].Index := 0;
        a_6[3].Result := 2;
        a_6[3].Method := nil;

        a_6[4].Str  := 'gg';
        a_6[4].Index := 0;
        a_6[4].Result := 2;
        a_6[4].Method := nil;

        a_6[5].Str  := 'bl';
        a_6[5].Index := 0;
        a_6[5].Result := 1;
        a_6[5].Method := nil;

        a_6[6].Str  := 'mm';
        a_6[6].Index := 0;
        a_6[6].Result := 2;
        a_6[6].Method := nil;

        a_6[7].Str  := 'nn';
        a_6[7].Index := 0;
        a_6[7].Result := 2;
        a_6[7].Method := nil;

        a_6[8].Str  := 'pp';
        a_6[8].Index := 0;
        a_6[8].Result := 2;
        a_6[8].Method := nil;

        a_6[9].Str  := 'rr';
        a_6[9].Index := 0;
        a_6[9].Result := 2;
        a_6[9].Method := nil;

        a_6[10].Str  := 'at';
        a_6[10].Index := 0;
        a_6[10].Result := 1;
        a_6[10].Method := nil;

        a_6[11].Str  := 'tt';
        a_6[11].Index := 0;
        a_6[11].Result := 2;
        a_6[11].Method := nil;

        a_6[12].Str  := 'iz';
        a_6[12].Index := 0;
        a_6[12].Result := 1;
        a_6[12].Method := nil;

    SetLength(a_7, 25);
        a_7[0].Str  := 'anci';
        a_7[0].Index := -1;
        a_7[0].Result := 3;
        a_7[0].Method := nil;

        a_7[1].Str  := 'enci';
        a_7[1].Index := -1;
        a_7[1].Result := 2;
        a_7[1].Method := nil;

        a_7[2].Str  := 'ogi';
        a_7[2].Index := -1;
        a_7[2].Result := 14;
        a_7[2].Method := nil;

        a_7[3].Str  := 'li';
        a_7[3].Index := -1;
        a_7[3].Result := 16;
        a_7[3].Method := nil;

        a_7[4].Str  := 'bli';
        a_7[4].Index := 3;
        a_7[4].Result := 12;
        a_7[4].Method := nil;

        a_7[5].Str  := 'abli';
        a_7[5].Index := 4;
        a_7[5].Result := 4;
        a_7[5].Method := nil;

        a_7[6].Str  := 'alli';
        a_7[6].Index := 3;
        a_7[6].Result := 8;
        a_7[6].Method := nil;

        a_7[7].Str  := 'fulli';
        a_7[7].Index := 3;
        a_7[7].Result := 9;
        a_7[7].Method := nil;

        a_7[8].Str  := 'lessli';
        a_7[8].Index := 3;
        a_7[8].Result := 15;
        a_7[8].Method := nil;

        a_7[9].Str  := 'ousli';
        a_7[9].Index := 3;
        a_7[9].Result := 10;
        a_7[9].Method := nil;

        a_7[10].Str  := 'entli';
        a_7[10].Index := 3;
        a_7[10].Result := 5;
        a_7[10].Method := nil;

        a_7[11].Str  := 'aliti';
        a_7[11].Index := -1;
        a_7[11].Result := 8;
        a_7[11].Method := nil;

        a_7[12].Str  := 'biliti';
        a_7[12].Index := -1;
        a_7[12].Result := 12;
        a_7[12].Method := nil;

        a_7[13].Str  := 'iviti';
        a_7[13].Index := -1;
        a_7[13].Result := 11;
        a_7[13].Method := nil;

        a_7[14].Str  := 'tional';
        a_7[14].Index := -1;
        a_7[14].Result := 1;
        a_7[14].Method := nil;

        a_7[15].Str  := 'ational';
        a_7[15].Index := 14;
        a_7[15].Result := 7;
        a_7[15].Method := nil;

        a_7[16].Str  := 'alism';
        a_7[16].Index := -1;
        a_7[16].Result := 8;
        a_7[16].Method := nil;

        a_7[17].Str  := 'ation';
        a_7[17].Index := -1;
        a_7[17].Result := 7;
        a_7[17].Method := nil;

        a_7[18].Str  := 'ization';
        a_7[18].Index := 17;
        a_7[18].Result := 6;
        a_7[18].Method := nil;

        a_7[19].Str  := 'izer';
        a_7[19].Index := -1;
        a_7[19].Result := 6;
        a_7[19].Method := nil;

        a_7[20].Str  := 'ator';
        a_7[20].Index := -1;
        a_7[20].Result := 7;
        a_7[20].Method := nil;

        a_7[21].Str  := 'iveness';
        a_7[21].Index := -1;
        a_7[21].Result := 11;
        a_7[21].Method := nil;

        a_7[22].Str  := 'fulness';
        a_7[22].Index := -1;
        a_7[22].Result := 9;
        a_7[22].Method := nil;

        a_7[23].Str  := 'ousness';
        a_7[23].Index := -1;
        a_7[23].Result := 10;
        a_7[23].Method := nil;

        a_7[24].Str  := 'ogist';
        a_7[24].Index := -1;
        a_7[24].Result := 13;
        a_7[24].Method := nil;

    SetLength(a_8, 9);
        a_8[0].Str  := 'icate';
        a_8[0].Index := -1;
        a_8[0].Result := 4;
        a_8[0].Method := nil;

        a_8[1].Str  := 'ative';
        a_8[1].Index := -1;
        a_8[1].Result := 6;
        a_8[1].Method := nil;

        a_8[2].Str  := 'alize';
        a_8[2].Index := -1;
        a_8[2].Result := 3;
        a_8[2].Method := nil;

        a_8[3].Str  := 'iciti';
        a_8[3].Index := -1;
        a_8[3].Result := 4;
        a_8[3].Method := nil;

        a_8[4].Str  := 'ical';
        a_8[4].Index := -1;
        a_8[4].Result := 4;
        a_8[4].Method := nil;

        a_8[5].Str  := 'tional';
        a_8[5].Index := -1;
        a_8[5].Result := 1;
        a_8[5].Method := nil;

        a_8[6].Str  := 'ational';
        a_8[6].Index := 5;
        a_8[6].Result := 2;
        a_8[6].Method := nil;

        a_8[7].Str  := 'ful';
        a_8[7].Index := -1;
        a_8[7].Result := 5;
        a_8[7].Method := nil;

        a_8[8].Str  := 'ness';
        a_8[8].Index := -1;
        a_8[8].Result := 5;
        a_8[8].Method := nil;

    SetLength(a_9, 18);
        a_9[0].Str  := 'ic';
        a_9[0].Index := -1;
        a_9[0].Result := 1;
        a_9[0].Method := nil;

        a_9[1].Str  := 'ance';
        a_9[1].Index := -1;
        a_9[1].Result := 1;
        a_9[1].Method := nil;

        a_9[2].Str  := 'ence';
        a_9[2].Index := -1;
        a_9[2].Result := 1;
        a_9[2].Method := nil;

        a_9[3].Str  := 'able';
        a_9[3].Index := -1;
        a_9[3].Result := 1;
        a_9[3].Method := nil;

        a_9[4].Str  := 'ible';
        a_9[4].Index := -1;
        a_9[4].Result := 1;
        a_9[4].Method := nil;

        a_9[5].Str  := 'ate';
        a_9[5].Index := -1;
        a_9[5].Result := 1;
        a_9[5].Method := nil;

        a_9[6].Str  := 'ive';
        a_9[6].Index := -1;
        a_9[6].Result := 1;
        a_9[6].Method := nil;

        a_9[7].Str  := 'ize';
        a_9[7].Index := -1;
        a_9[7].Result := 1;
        a_9[7].Method := nil;

        a_9[8].Str  := 'iti';
        a_9[8].Index := -1;
        a_9[8].Result := 1;
        a_9[8].Method := nil;

        a_9[9].Str  := 'al';
        a_9[9].Index := -1;
        a_9[9].Result := 1;
        a_9[9].Method := nil;

        a_9[10].Str  := 'ism';
        a_9[10].Index := -1;
        a_9[10].Result := 1;
        a_9[10].Method := nil;

        a_9[11].Str  := 'ion';
        a_9[11].Index := -1;
        a_9[11].Result := 2;
        a_9[11].Method := nil;

        a_9[12].Str  := 'er';
        a_9[12].Index := -1;
        a_9[12].Result := 1;
        a_9[12].Method := nil;

        a_9[13].Str  := 'ous';
        a_9[13].Index := -1;
        a_9[13].Result := 1;
        a_9[13].Method := nil;

        a_9[14].Str  := 'ant';
        a_9[14].Index := -1;
        a_9[14].Result := 1;
        a_9[14].Method := nil;

        a_9[15].Str  := 'ent';
        a_9[15].Index := -1;
        a_9[15].Result := 1;
        a_9[15].Method := nil;

        a_9[16].Str  := 'ment';
        a_9[16].Index := 15;
        a_9[16].Result := 1;
        a_9[16].Method := nil;

        a_9[17].Str  := 'ement';
        a_9[17].Index := 16;
        a_9[17].Result := 1;
        a_9[17].Method := nil;

    SetLength(a_10, 2);
        a_10[0].Str  := 'e';
        a_10[0].Index := -1;
        a_10[0].Result := 1;
        a_10[0].Method := nil;

        a_10[1].Str  := 'l';
        a_10[1].Index := -1;
        a_10[1].Result := 2;
        a_10[1].Method := nil;

    SetLength(a_11, 15);
        a_11[0].Str  := 'andes';
        a_11[0].Index := -1;
        a_11[0].Result := -1;
        a_11[0].Method := nil;

        a_11[1].Str  := 'atlas';
        a_11[1].Index := -1;
        a_11[1].Result := -1;
        a_11[1].Method := nil;

        a_11[2].Str  := 'bias';
        a_11[2].Index := -1;
        a_11[2].Result := -1;
        a_11[2].Method := nil;

        a_11[3].Str  := 'cosmos';
        a_11[3].Index := -1;
        a_11[3].Result := -1;
        a_11[3].Method := nil;

        a_11[4].Str  := 'early';
        a_11[4].Index := -1;
        a_11[4].Result := 6;
        a_11[4].Method := nil;

        a_11[5].Str  := 'gently';
        a_11[5].Index := -1;
        a_11[5].Result := 4;
        a_11[5].Method := nil;

        a_11[6].Str  := 'howe';
        a_11[6].Index := -1;
        a_11[6].Result := -1;
        a_11[6].Method := nil;

        a_11[7].Str  := 'idly';
        a_11[7].Index := -1;
        a_11[7].Result := 3;
        a_11[7].Method := nil;

        a_11[8].Str  := 'news';
        a_11[8].Index := -1;
        a_11[8].Result := -1;
        a_11[8].Method := nil;

        a_11[9].Str  := 'only';
        a_11[9].Index := -1;
        a_11[9].Result := 7;
        a_11[9].Method := nil;

        a_11[10].Str  := 'singly';
        a_11[10].Index := -1;
        a_11[10].Result := 8;
        a_11[10].Method := nil;

        a_11[11].Str  := 'skies';
        a_11[11].Index := -1;
        a_11[11].Result := 2;
        a_11[11].Method := nil;

        a_11[12].Str  := 'skis';
        a_11[12].Index := -1;
        a_11[12].Result := 1;
        a_11[12].Method := nil;

        a_11[13].Str  := 'sky';
        a_11[13].Index := -1;
        a_11[13].Result := -1;
        a_11[13].Method := nil;

        a_11[14].Str  := 'ugly';
        a_11[14].Index := -1;
        a_11[14].Result := 5;
        a_11[14].Method := nil;

End;

Function TEnglishStemmer.r_shortv : Boolean;
Var
    v_1 : Integer;
Label
    lab0,
    lab1;
Begin
    Repeat
        v_1 := FLimit - FCursor;
        If (Not (OutGroupingBk(g_v_WXY, 89, 121))) Then
        Begin
            goto lab0;
        End;
        If (Not (InGroupingBk(g_v, 97, 121))) Then
        Begin
            goto lab0;
        End;
        If (Not (OutGroupingBk(g_v, 97, 121))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        FCursor := FLimit - v_1;
        If (Not (OutGroupingBk(g_v, 97, 121))) Then
        Begin
            goto lab1;
        End;
        If (Not (InGroupingBk(g_v, 97, 121))) Then
        Begin
            goto lab1;
        End;
        If FCursor > FBkLimit Then
        Begin
            goto lab1;
        End;
        Break;
lab1:
        FCursor := FLimit - v_1;
        If (Not (EqSBk('past'))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TEnglishStemmer.stem : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
    v_3 : Integer;
    v_4 : Integer;
    v_5 : Integer;
    v_6 : Integer;
    v_7 : Integer;
    v_8 : Integer;
    v_9 : Integer;
    v_10 : Integer;
    v_11 : Integer;
    v_12 : Integer;
    v_13 : Integer;
    v_14 : Integer;
    v_15 : Integer;
    v_16 : Integer;
    v_17 : Integer;
    v_18 : Integer;
    v_19 : Integer;
    v_20 : Integer;
    v_21 : Integer;
    v_22 : Integer;
    v_23 : Integer;
    v_24 : Integer;
    v_25 : Integer;
    v_26 : Integer;
    v_27 : Integer;
    v_28 : Integer;
    v_29 : Integer;
    AmongVar : Integer;
    C : Integer;
    B_Y_found : Boolean;
    I_p2 : Integer;
    I_p1 : Integer;
Label
    lab0,
    lab1,
    lab2,
    lab3,
    lab4,
    lab5,
    lab6,
    lab7,
    lab8,
    lab9,
    lab10,
    lab11,
    lab12,
    lab13,
    lab14,
    lab15,
    lab16,
    lab17,
    lab18,
    lab19,
    lab20,
    lab21,
    lab22,
    lab23,
    lab24,
    lab25,
    lab26,
    lab27,
    lab28,
    lab29,
    lab30,
    lab31,
    lab32,
    lab33;
Begin
    Repeat
        v_1 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_11, 15);
        If (AmongVar = 0) Then
        Begin
            goto lab0;
        End;
        FKet := FCursor;
        If FCursor < FLimit Then
        Begin
            goto lab0;
        End;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('ski');
            End;
            2:
            Begin
                SliceFrom('sky');
            End;
            3:
            Begin
                SliceFrom('idl');
            End;
            4:
            Begin
                SliceFrom('gentl');
            End;
            5:
            Begin
                SliceFrom('ugli');
            End;
            6:
            Begin
                SliceFrom('earli');
            End;
            7:
            Begin
                SliceFrom('onli');
            End;
            8:
            Begin
                SliceFrom('singl');
            End;
        End;
        Break;
lab0:
        FCursor := v_1;
        Begin
            C := FCursor + 3;
            If (C > FLimit) Then
            Begin
                goto lab2;
            End;
            FCursor := C;
        End;
        goto lab1;
lab2:
        Break;
lab1:
        FCursor := v_1;
        B_Y_found := False;
        v_2 := FCursor;
        FBra := FCursor;
        If (Not (EqS(''''))) Then
        Begin
            goto lab4;
        End;
        FKet := FCursor;
        SliceDel;
lab4:
        FCursor := v_2;
        v_3 := FCursor;
        FBra := FCursor;
        If (Not (EqS('y'))) Then
        Begin
            goto lab5;
        End;
        FKet := FCursor;
        SliceFrom('Y');
        B_Y_found := True;
lab5:
        FCursor := v_3;
        v_4 := FCursor;
lab7:
        Begin
            v_5 := FCursor;
            While True Do
            Begin
                v_6 := FCursor;
                If (Not (InGrouping(g_v, 97, 121))) Then
                Begin
                    goto lab9;
                End;
                FBra := FCursor;
                If (Not (EqS('y'))) Then
                Begin
                    goto lab9;
                End;
                FKet := FCursor;
                FCursor := v_6;
                Break;
lab9:
                FCursor := v_6;
                If (FCursor >= FLimit) Then
                Begin
                    goto lab8;
                End;
                Inc(FCursor);
            End;
            SliceFrom('Y');
            B_Y_found := True;
            goto lab7;
lab8:
            FCursor := v_5;
        End;
lab6:
        FCursor := v_4;
lab3:
        I_p1 := FLimit;
        I_p2 := FLimit;
        v_7 := FCursor;
        Repeat
            v_8 := FCursor;
            If (FindAmong(a_0, 9) = 0) Then
            Begin
                goto lab12;
            End;
            Break;
lab12:
            FCursor := v_8;
            If (Not (GoOutGrouping(g_v, 97, 121))) Then
            Begin
                goto lab11;
            End;
            Inc(FCursor);
            If (Not (GoInGrouping(g_v, 97, 121))) Then
            Begin
                goto lab11;
            End;
            Inc(FCursor);
        Until True;
        I_p1 := FCursor;
        If (Not (GoOutGrouping(g_v, 97, 121))) Then
        Begin
            goto lab11;
        End;
        Inc(FCursor);
        If (Not (GoInGrouping(g_v, 97, 121))) Then
        Begin
            goto lab11;
        End;
        Inc(FCursor);
        I_p2 := FCursor;
lab11:
        FCursor := v_7;
lab10:
        FBkLimit := FCursor; FCursor := FLimit;
        v_9 := FLimit - FCursor;
        v_10 := FLimit - FCursor;
        FKet := FCursor;
        If (FindAmongBk(a_1, 3) = 0) Then
        Begin
            FCursor := FLimit - v_10;
            goto lab14;
        End;
        FBra := FCursor;
        SliceDel;
lab14:
        FKet := FCursor;
        AmongVar := FindAmongBk(a_2, 6);
        If (AmongVar = 0) Then
        Begin
            goto lab13;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('ss');
            End;
            2:
            Begin
                Repeat
                    v_11 := FLimit - FCursor;
                    Begin
                        C := FCursor - 2;
                        If (C < FBkLimit) Then
                        Begin
                            goto lab15;
                        End;
                        FCursor := C;
                    End;
                    SliceFrom('i');
                    Break;
lab15:
                    FCursor := FLimit - v_11;
                    SliceFrom('ie');
                Until True;
            End;
            3:
            Begin
                If (FCursor <= FBkLimit) Then
                Begin
                    goto lab13;
                End;
                Dec(FCursor);
                If (Not (GoOutGroupingBk(g_v, 97, 121))) Then
                Begin
                    goto lab13;
                End;
                Dec(FCursor);
                SliceDel;
            End;
        End;
lab13:
        FCursor := FLimit - v_9;
        v_12 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_5, 7);
        FBra := FCursor;
        Repeat
            v_13 := FLimit - FCursor;
            Case AmongVar Of
                1:
                Begin
                    v_14 := FLimit - FCursor;
                    If I_p1 > FCursor Then
                    Begin
                        goto lab18;
                    End;
                    Repeat
                        v_15 := FLimit - FCursor;
                        If (FindAmongBk(a_3, 3) = 0) Then
                        Begin
                            goto lab19;
                        End;
                        If FCursor > FBkLimit Then
                        Begin
                            goto lab19;
                        End;
                        Break;
lab19:
                        FCursor := FLimit - v_15;
                        SliceFrom('ee');
                    Until True;
lab18:
                    FCursor := FLimit - v_14;
                End;
                2:
                Begin
                    goto lab17;
                End;
                3:
                Begin
                    AmongVar := FindAmongBk(a_4, 7);
                    If (AmongVar = 0) Then
                    Begin
                        goto lab17;
                    End;
                    Case AmongVar Of
                        1:
                        Begin
                            v_16 := FLimit - FCursor;
                            If (Not (OutGroupingBk(g_v, 97, 121))) Then
                            Begin
                                goto lab17;
                            End;
                            If FCursor > FBkLimit Then
                            Begin
                                goto lab17;
                            End;
                            FCursor := FLimit - v_16;
                            FBra := FCursor;
                            SliceFrom('ie');
                        End;
                        2:
                        Begin
                            If FCursor > FBkLimit Then
                            Begin
                                goto lab17;
                            End;
                        End;
                    End;
                End;
            End;
            Break;
lab17:
            FCursor := FLimit - v_13;
            v_17 := FLimit - FCursor;
            If (Not (GoOutGroupingBk(g_v, 97, 121))) Then
            Begin
                goto lab16;
            End;
            Dec(FCursor);
            FCursor := FLimit - v_17;
            SliceDel;
            FKet := FCursor;
            FBra := FCursor;
            v_18 := FLimit - FCursor;
            AmongVar := FindAmongBk(a_6, 13);
            Case AmongVar Of
                1:
                Begin
                    SliceFrom('e');
                    goto lab16;
                End;
                2:
                Begin
                    Begin
                        v_19 := FLimit - FCursor;
                        If (Not (InGroupingBk(g_aeo, 97, 111))) Then
                        Begin
                            goto lab20;
                        End;
                        If FCursor > FBkLimit Then
                        Begin
                            goto lab20;
                        End;
                        goto lab16;
lab20:
                        FCursor := FLimit - v_19;
                    End;
                End;
                3:
                Begin
                    If FCursor <> I_p1 Then
                    Begin
                        goto lab16;
                    End;
                    v_20 := FLimit - FCursor;
                    If (Not r_shortv) Then
                    Begin
                        goto lab16;
                    End;
                    FCursor := FLimit - v_20;
                    SliceFrom('e');
                    goto lab16;
                End;
            End;
            FCursor := FLimit - v_18;
            FKet := FCursor;
            If (FCursor <= FBkLimit) Then
            Begin
                goto lab16;
            End;
            Dec(FCursor);
            FBra := FCursor;
            SliceDel;
        Until True;
lab16:
        FCursor := FLimit - v_12;
        v_21 := FLimit - FCursor;
        FKet := FCursor;
        Repeat
            If (Not (EqSBk('y'))) Then
            Begin
                goto lab22;
            End;
            Break;
lab22:
            If (Not (EqSBk('Y'))) Then
            Begin
                goto lab21;
            End;
        Until True;
        FBra := FCursor;
        If (Not (OutGroupingBk(g_v, 97, 121))) Then
        Begin
            goto lab21;
        End;
        If FCursor <= FBkLimit Then
        Begin
            goto lab21;
        End;
        SliceFrom('i');
lab21:
        FCursor := FLimit - v_21;
        v_22 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_7, 25);
        If (AmongVar = 0) Then
        Begin
            goto lab23;
        End;
        FBra := FCursor;
        If I_p1 > FCursor Then
        Begin
            goto lab23;
        End;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('tion');
            End;
            2:
            Begin
                SliceFrom('ence');
            End;
            3:
            Begin
                SliceFrom('ance');
            End;
            4:
            Begin
                SliceFrom('able');
            End;
            5:
            Begin
                SliceFrom('ent');
            End;
            6:
            Begin
                SliceFrom('ize');
            End;
            7:
            Begin
                SliceFrom('ate');
            End;
            8:
            Begin
                SliceFrom('al');
            End;
            9:
            Begin
                SliceFrom('ful');
            End;
            10:
            Begin
                SliceFrom('ous');
            End;
            11:
            Begin
                SliceFrom('ive');
            End;
            12:
            Begin
                SliceFrom('ble');
            End;
            13:
            Begin
                SliceFrom('og');
            End;
            14:
            Begin
                If (Not (EqSBk('l'))) Then
                Begin
                    goto lab23;
                End;
                SliceFrom('og');
            End;
            15:
            Begin
                SliceFrom('less');
            End;
            16:
            Begin
                If (Not (InGroupingBk(g_valid_LI, 99, 116))) Then
                Begin
                    goto lab23;
                End;
                SliceDel;
            End;
        End;
lab23:
        FCursor := FLimit - v_22;
        v_23 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_8, 9);
        If (AmongVar = 0) Then
        Begin
            goto lab24;
        End;
        FBra := FCursor;
        If I_p1 > FCursor Then
        Begin
            goto lab24;
        End;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('tion');
            End;
            2:
            Begin
                SliceFrom('ate');
            End;
            3:
            Begin
                SliceFrom('al');
            End;
            4:
            Begin
                SliceFrom('ic');
            End;
            5:
            Begin
                SliceDel;
            End;
            6:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab24;
                End;
                SliceDel;
            End;
        End;
lab24:
        FCursor := FLimit - v_23;
        v_24 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_9, 18);
        If (AmongVar = 0) Then
        Begin
            goto lab25;
        End;
        FBra := FCursor;
        If I_p2 > FCursor Then
        Begin
            goto lab25;
        End;
        Case AmongVar Of
            1:
            Begin
                SliceDel;
            End;
            2:
            Begin
                Repeat
                    If (Not (EqSBk('s'))) Then
                    Begin
                        goto lab26;
                    End;
                    Break;
lab26:
                    If (Not (EqSBk('t'))) Then
                    Begin
                        goto lab25;
                    End;
                Until True;
                SliceDel;
            End;
        End;
lab25:
        FCursor := FLimit - v_24;
        v_25 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_10, 2);
        If (AmongVar = 0) Then
        Begin
            goto lab27;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                Repeat
                    If I_p2 > FCursor Then
                    Begin
                        goto lab28;
                    End;
                    Break;
lab28:
                    If I_p1 > FCursor Then
                    Begin
                        goto lab27;
                    End;
                    Begin
                        v_26 := FLimit - FCursor;
                        If (Not r_shortv) Then
                        Begin
                            goto lab29;
                        End;
                        goto lab27;
lab29:
                        FCursor := FLimit - v_26;
                    End;
                Until True;
                SliceDel;
            End;
            2:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab27;
                End;
                If (Not (EqSBk('l'))) Then
                Begin
                    goto lab27;
                End;
                SliceDel;
            End;
        End;
lab27:
        FCursor := FLimit - v_25;
        FCursor := FBkLimit;
        v_27 := FCursor;
        If (Not (B_Y_found)) Then
        Begin
            goto lab30;
        End;
lab31:
        Begin
            v_28 := FCursor;
            While True Do
            Begin
                v_29 := FCursor;
                FBra := FCursor;
                If (Not (EqS('Y'))) Then
                Begin
                    goto lab33;
                End;
                FKet := FCursor;
                FCursor := v_29;
                Break;
lab33:
                FCursor := v_29;
                If (FCursor >= FLimit) Then
                Begin
                    goto lab32;
                End;
                Inc(FCursor);
            End;
            SliceFrom('y');
            goto lab31;
lab32:
            FCursor := v_28;
        End;
lab30:
        FCursor := v_27;
    Until True;
    Result := True;
End;

End.
