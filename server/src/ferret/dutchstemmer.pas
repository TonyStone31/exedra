// Generated from dutch.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit DutchStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TDutchStemmer = Class(TSnowballProgram)
    private
        I_p2 : Integer;
        I_p1 : Integer;
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
        Function r_measure : Boolean;
        Function r_Step_1c : Boolean;
        Function r_lengthen_V : Boolean;
        Function r_V : Boolean;
        Function r_C : Boolean;
End;

Implementation

Const
    g_E : Array [0..16] Of Char = (
        Chr(1),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(120)
    );

Const
    g_AIOU : Array [0..19] Of Char = (
        Chr(1),
        Chr(65),
        Chr(16),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(128),
        Chr(11),
        Chr(120),
        Chr(46),
        Chr(15)
    );

Const
    g_AEIOU : Array [0..19] Of Char = (
        Chr(17),
        Chr(65),
        Chr(16),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(128),
        Chr(139),
        Chr(127),
        Chr(46),
        Chr(15)
    );

Const
    g_v : Array [0..19] Of Char = (
        Chr(17),
        Chr(65),
        Chr(16),
        Chr(1),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(128),
        Chr(139),
        Chr(127),
        Chr(46),
        Chr(15)
    );

Const
    g_v_WX : Array [0..19] Of Char = (
        Chr(17),
        Chr(65),
        Chr(208),
        Chr(1),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(128),
        Chr(139),
        Chr(127),
        Chr(46),
        Chr(15)
    );

Constructor TDutchStemmer.Create;
Begin
    SetLength(a_0, 21);
        a_0[0].Str  := 'a';
        a_0[0].Index := -1;
        a_0[0].Result := 1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'e';
        a_0[1].Index := -1;
        a_0[1].Result := 2;
        a_0[1].Method := nil;

        a_0[2].Str  := 'o';
        a_0[2].Index := -1;
        a_0[2].Result := 1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'u';
        a_0[3].Index := -1;
        a_0[3].Result := 1;
        a_0[3].Method := nil;

        a_0[4].Str  := #224;
        a_0[4].Index := -1;
        a_0[4].Result := 1;
        a_0[4].Method := nil;

        a_0[5].Str  := #225;
        a_0[5].Index := -1;
        a_0[5].Result := 1;
        a_0[5].Method := nil;

        a_0[6].Str  := #226;
        a_0[6].Index := -1;
        a_0[6].Result := 1;
        a_0[6].Method := nil;

        a_0[7].Str  := #228;
        a_0[7].Index := -1;
        a_0[7].Result := 1;
        a_0[7].Method := nil;

        a_0[8].Str  := #232;
        a_0[8].Index := -1;
        a_0[8].Result := 2;
        a_0[8].Method := nil;

        a_0[9].Str  := #233;
        a_0[9].Index := -1;
        a_0[9].Result := 2;
        a_0[9].Method := nil;

        a_0[10].Str  := #234;
        a_0[10].Index := -1;
        a_0[10].Result := 2;
        a_0[10].Method := nil;

        a_0[11].Str  := 'e'#235;
        a_0[11].Index := -1;
        a_0[11].Result := 3;
        a_0[11].Method := nil;

        a_0[12].Str  := 'i'#235;
        a_0[12].Index := -1;
        a_0[12].Result := 4;
        a_0[12].Method := nil;

        a_0[13].Str  := #242;
        a_0[13].Index := -1;
        a_0[13].Result := 1;
        a_0[13].Method := nil;

        a_0[14].Str  := #243;
        a_0[14].Index := -1;
        a_0[14].Result := 1;
        a_0[14].Method := nil;

        a_0[15].Str  := #244;
        a_0[15].Index := -1;
        a_0[15].Result := 1;
        a_0[15].Method := nil;

        a_0[16].Str  := #246;
        a_0[16].Index := -1;
        a_0[16].Result := 1;
        a_0[16].Method := nil;

        a_0[17].Str  := #249;
        a_0[17].Index := -1;
        a_0[17].Result := 1;
        a_0[17].Method := nil;

        a_0[18].Str  := #250;
        a_0[18].Index := -1;
        a_0[18].Result := 1;
        a_0[18].Method := nil;

        a_0[19].Str  := #251;
        a_0[19].Index := -1;
        a_0[19].Result := 1;
        a_0[19].Method := nil;

        a_0[20].Str  := #252;
        a_0[20].Index := -1;
        a_0[20].Result := 1;
        a_0[20].Method := nil;

    SetLength(a_1, 8);
        a_1[0].Str  := 'nde';
        a_1[0].Index := -1;
        a_1[0].Result := 8;
        a_1[0].Method := nil;

        a_1[1].Str  := 'en';
        a_1[1].Index := -1;
        a_1[1].Result := 7;
        a_1[1].Method := nil;

        a_1[2].Str  := 's';
        a_1[2].Index := -1;
        a_1[2].Result := 2;
        a_1[2].Method := nil;

        a_1[3].Str  := '''s';
        a_1[3].Index := 2;
        a_1[3].Result := 1;
        a_1[3].Method := nil;

        a_1[4].Str  := 'es';
        a_1[4].Index := 2;
        a_1[4].Result := 4;
        a_1[4].Method := nil;

        a_1[5].Str  := 'ies';
        a_1[5].Index := 4;
        a_1[5].Result := 3;
        a_1[5].Method := nil;

        a_1[6].Str  := 'aus';
        a_1[6].Index := 2;
        a_1[6].Result := 6;
        a_1[6].Method := nil;

        a_1[7].Str  := #233's';
        a_1[7].Index := 2;
        a_1[7].Result := 5;
        a_1[7].Method := nil;

    SetLength(a_2, 11);
        a_2[0].Str  := 'de';
        a_2[0].Index := -1;
        a_2[0].Result := 5;
        a_2[0].Method := nil;

        a_2[1].Str  := 'ge';
        a_2[1].Index := -1;
        a_2[1].Result := 2;
        a_2[1].Method := nil;

        a_2[2].Str  := 'ische';
        a_2[2].Index := -1;
        a_2[2].Result := 4;
        a_2[2].Method := nil;

        a_2[3].Str  := 'je';
        a_2[3].Index := -1;
        a_2[3].Result := 1;
        a_2[3].Method := nil;

        a_2[4].Str  := 'lijke';
        a_2[4].Index := -1;
        a_2[4].Result := 3;
        a_2[4].Method := nil;

        a_2[5].Str  := 'le';
        a_2[5].Index := -1;
        a_2[5].Result := 9;
        a_2[5].Method := nil;

        a_2[6].Str  := 'ene';
        a_2[6].Index := -1;
        a_2[6].Result := 10;
        a_2[6].Method := nil;

        a_2[7].Str  := 're';
        a_2[7].Index := -1;
        a_2[7].Result := 8;
        a_2[7].Method := nil;

        a_2[8].Str  := 'se';
        a_2[8].Index := -1;
        a_2[8].Result := 7;
        a_2[8].Method := nil;

        a_2[9].Str  := 'te';
        a_2[9].Index := -1;
        a_2[9].Result := 6;
        a_2[9].Method := nil;

        a_2[10].Str  := 'ieve';
        a_2[10].Index := -1;
        a_2[10].Result := 11;
        a_2[10].Method := nil;

    SetLength(a_3, 14);
        a_3[0].Str  := 'heid';
        a_3[0].Index := -1;
        a_3[0].Result := 3;
        a_3[0].Method := nil;

        a_3[1].Str  := 'fie';
        a_3[1].Index := -1;
        a_3[1].Result := 7;
        a_3[1].Method := nil;

        a_3[2].Str  := 'gie';
        a_3[2].Index := -1;
        a_3[2].Result := 8;
        a_3[2].Method := nil;

        a_3[3].Str  := 'atie';
        a_3[3].Index := -1;
        a_3[3].Result := 1;
        a_3[3].Method := nil;

        a_3[4].Str  := 'isme';
        a_3[4].Index := -1;
        a_3[4].Result := 5;
        a_3[4].Method := nil;

        a_3[5].Str  := 'ing';
        a_3[5].Index := -1;
        a_3[5].Result := 5;
        a_3[5].Method := nil;

        a_3[6].Str  := 'arij';
        a_3[6].Index := -1;
        a_3[6].Result := 6;
        a_3[6].Method := nil;

        a_3[7].Str  := 'erij';
        a_3[7].Index := -1;
        a_3[7].Result := 5;
        a_3[7].Method := nil;

        a_3[8].Str  := 'sel';
        a_3[8].Index := -1;
        a_3[8].Result := 3;
        a_3[8].Method := nil;

        a_3[9].Str  := 'rder';
        a_3[9].Index := -1;
        a_3[9].Result := 4;
        a_3[9].Method := nil;

        a_3[10].Str  := 'ster';
        a_3[10].Index := -1;
        a_3[10].Result := 3;
        a_3[10].Method := nil;

        a_3[11].Str  := 'iteit';
        a_3[11].Index := -1;
        a_3[11].Result := 2;
        a_3[11].Method := nil;

        a_3[12].Str  := 'dst';
        a_3[12].Index := -1;
        a_3[12].Result := 10;
        a_3[12].Method := nil;

        a_3[13].Str  := 'tst';
        a_3[13].Index := -1;
        a_3[13].Result := 9;
        a_3[13].Method := nil;

    SetLength(a_4, 16);
        a_4[0].Str  := 'end';
        a_4[0].Index := -1;
        a_4[0].Result := 9;
        a_4[0].Method := nil;

        a_4[1].Str  := 'atief';
        a_4[1].Index := -1;
        a_4[1].Result := 2;
        a_4[1].Method := nil;

        a_4[2].Str  := 'erig';
        a_4[2].Index := -1;
        a_4[2].Result := 9;
        a_4[2].Method := nil;

        a_4[3].Str  := 'achtig';
        a_4[3].Index := -1;
        a_4[3].Result := 3;
        a_4[3].Method := nil;

        a_4[4].Str  := 'ioneel';
        a_4[4].Index := -1;
        a_4[4].Result := 1;
        a_4[4].Method := nil;

        a_4[5].Str  := 'baar';
        a_4[5].Index := -1;
        a_4[5].Result := 3;
        a_4[5].Method := nil;

        a_4[6].Str  := 'laar';
        a_4[6].Index := -1;
        a_4[6].Result := 5;
        a_4[6].Method := nil;

        a_4[7].Str  := 'naar';
        a_4[7].Index := -1;
        a_4[7].Result := 4;
        a_4[7].Method := nil;

        a_4[8].Str  := 'raar';
        a_4[8].Index := -1;
        a_4[8].Result := 6;
        a_4[8].Method := nil;

        a_4[9].Str  := 'eriger';
        a_4[9].Index := -1;
        a_4[9].Result := 9;
        a_4[9].Method := nil;

        a_4[10].Str  := 'achtiger';
        a_4[10].Index := -1;
        a_4[10].Result := 3;
        a_4[10].Method := nil;

        a_4[11].Str  := 'lijker';
        a_4[11].Index := -1;
        a_4[11].Result := 8;
        a_4[11].Method := nil;

        a_4[12].Str  := 'tant';
        a_4[12].Index := -1;
        a_4[12].Result := 7;
        a_4[12].Method := nil;

        a_4[13].Str  := 'erigst';
        a_4[13].Index := -1;
        a_4[13].Result := 9;
        a_4[13].Method := nil;

        a_4[14].Str  := 'achtigst';
        a_4[14].Index := -1;
        a_4[14].Result := 3;
        a_4[14].Method := nil;

        a_4[15].Str  := 'lijkst';
        a_4[15].Index := -1;
        a_4[15].Result := 8;
        a_4[15].Method := nil;

    SetLength(a_5, 3);
        a_5[0].Str  := 'ig';
        a_5[0].Index := -1;
        a_5[0].Result := 1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'iger';
        a_5[1].Index := -1;
        a_5[1].Result := 1;
        a_5[1].Method := nil;

        a_5[2].Str  := 'igst';
        a_5[2].Index := -1;
        a_5[2].Result := 1;
        a_5[2].Method := nil;

    SetLength(a_6, 3);
        a_6[0].Str  := 'ft';
        a_6[0].Index := -1;
        a_6[0].Result := 2;
        a_6[0].Method := nil;

        a_6[1].Str  := 'kt';
        a_6[1].Index := -1;
        a_6[1].Result := 1;
        a_6[1].Method := nil;

        a_6[2].Str  := 'pt';
        a_6[2].Index := -1;
        a_6[2].Result := 3;
        a_6[2].Method := nil;

    SetLength(a_7, 22);
        a_7[0].Str  := 'bb';
        a_7[0].Index := -1;
        a_7[0].Result := 1;
        a_7[0].Method := nil;

        a_7[1].Str  := 'cc';
        a_7[1].Index := -1;
        a_7[1].Result := 2;
        a_7[1].Method := nil;

        a_7[2].Str  := 'dd';
        a_7[2].Index := -1;
        a_7[2].Result := 3;
        a_7[2].Method := nil;

        a_7[3].Str  := 'ff';
        a_7[3].Index := -1;
        a_7[3].Result := 4;
        a_7[3].Method := nil;

        a_7[4].Str  := 'gg';
        a_7[4].Index := -1;
        a_7[4].Result := 5;
        a_7[4].Method := nil;

        a_7[5].Str  := 'hh';
        a_7[5].Index := -1;
        a_7[5].Result := 6;
        a_7[5].Method := nil;

        a_7[6].Str  := 'jj';
        a_7[6].Index := -1;
        a_7[6].Result := 7;
        a_7[6].Method := nil;

        a_7[7].Str  := 'kk';
        a_7[7].Index := -1;
        a_7[7].Result := 8;
        a_7[7].Method := nil;

        a_7[8].Str  := 'll';
        a_7[8].Index := -1;
        a_7[8].Result := 9;
        a_7[8].Method := nil;

        a_7[9].Str  := 'mm';
        a_7[9].Index := -1;
        a_7[9].Result := 10;
        a_7[9].Method := nil;

        a_7[10].Str  := 'nn';
        a_7[10].Index := -1;
        a_7[10].Result := 11;
        a_7[10].Method := nil;

        a_7[11].Str  := 'pp';
        a_7[11].Index := -1;
        a_7[11].Result := 12;
        a_7[11].Method := nil;

        a_7[12].Str  := 'qq';
        a_7[12].Index := -1;
        a_7[12].Result := 13;
        a_7[12].Method := nil;

        a_7[13].Str  := 'rr';
        a_7[13].Index := -1;
        a_7[13].Result := 14;
        a_7[13].Method := nil;

        a_7[14].Str  := 'ss';
        a_7[14].Index := -1;
        a_7[14].Result := 15;
        a_7[14].Method := nil;

        a_7[15].Str  := 'tt';
        a_7[15].Index := -1;
        a_7[15].Result := 16;
        a_7[15].Method := nil;

        a_7[16].Str  := 'v';
        a_7[16].Index := -1;
        a_7[16].Result := 4;
        a_7[16].Method := nil;

        a_7[17].Str  := 'vv';
        a_7[17].Index := 16;
        a_7[17].Result := 17;
        a_7[17].Method := nil;

        a_7[18].Str  := 'ww';
        a_7[18].Index := -1;
        a_7[18].Result := 18;
        a_7[18].Method := nil;

        a_7[19].Str  := 'xx';
        a_7[19].Index := -1;
        a_7[19].Result := 19;
        a_7[19].Method := nil;

        a_7[20].Str  := 'z';
        a_7[20].Index := -1;
        a_7[20].Result := 15;
        a_7[20].Method := nil;

        a_7[21].Str  := 'zz';
        a_7[21].Index := 20;
        a_7[21].Result := 20;
        a_7[21].Method := nil;

    SetLength(a_8, 2);
        a_8[0].Str  := 'd';
        a_8[0].Index := -1;
        a_8[0].Result := 1;
        a_8[0].Method := nil;

        a_8[1].Str  := 't';
        a_8[1].Index := -1;
        a_8[1].Result := 2;
        a_8[1].Method := nil;

    SetLength(a_9, 6);
        a_9[0].Str  := '';
        a_9[0].Index := -1;
        a_9[0].Result := -1;
        a_9[0].Method := nil;

        a_9[1].Str  := 'eft';
        a_9[1].Index := 0;
        a_9[1].Result := 1;
        a_9[1].Method := nil;

        a_9[2].Str  := 'vaa';
        a_9[2].Index := 0;
        a_9[2].Result := 1;
        a_9[2].Method := nil;

        a_9[3].Str  := 'val';
        a_9[3].Index := 0;
        a_9[3].Result := 1;
        a_9[3].Method := nil;

        a_9[4].Str  := 'vali';
        a_9[4].Index := 3;
        a_9[4].Result := -1;
        a_9[4].Method := nil;

        a_9[5].Str  := 'vare';
        a_9[5].Index := 0;
        a_9[5].Result := 1;
        a_9[5].Method := nil;

    SetLength(a_10, 2);
        a_10[0].Str  := #235;
        a_10[0].Index := -1;
        a_10[0].Result := 1;
        a_10[0].Method := nil;

        a_10[1].Str  := #239;
        a_10[1].Index := -1;
        a_10[1].Result := 2;
        a_10[1].Method := nil;

    SetLength(a_11, 2);
        a_11[0].Str  := #235;
        a_11[0].Index := -1;
        a_11[0].Result := 1;
        a_11[0].Method := nil;

        a_11[1].Str  := #239;
        a_11[1].Index := -1;
        a_11[1].Result := 2;
        a_11[1].Method := nil;

End;

Function TDutchStemmer.r_V : Boolean;
Var
    v_1 : Integer;
Label
    lab0;
Begin
    v_1 := FLimit - FCursor;
    Repeat
        If (Not (InGroupingBk(g_v, 97, 252))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk('ij'))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    FCursor := FLimit - v_1;
    Result := True;
End;

Function TDutchStemmer.r_C : Boolean;
Var
    v_1 : Integer;
Label
    lab0;
Begin
    v_1 := FLimit - FCursor;
    If (Not (EqSBk('ij'))) Then
    Begin
        goto lab0;
    End;
    Begin Result := False; Exit; End;
lab0:
    If (Not (OutGroupingBk(g_v, 97, 252))) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    FCursor := FLimit - v_1;
    Result := True;
End;

Function TDutchStemmer.r_lengthen_V : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
    v_3 : Integer;
    v_4 : Integer;
    v_5 : Integer;
    AmongVar : Integer;
    C : Integer;
    S_ch : AnsiString;
Label
    lab0,
    lab1,
    lab2,
    lab3,
    lab4,
    lab5;
Begin
    v_1 := FLimit - FCursor;
    If (Not (OutGroupingBk(g_v_WX, 97, 252))) Then
    Begin
        goto lab0;
    End;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_0, 21);
    If (AmongVar = 0) Then
    Begin
        goto lab0;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            v_2 := FLimit - FCursor;
            Repeat
                If (Not (OutGroupingBk(g_AEIOU, 97, 252))) Then
                Begin
                    goto lab1;
                End;
                Break;
lab1:
                If FCursor > FBkLimit Then
                Begin
                    goto lab0;
                End;
            Until True;
            FCursor := FLimit - v_2;
            S_ch := SliceTo();
            Begin
                C := FCursor;
                insert(FCursor, FCursor, S_ch);
                FCursor := C;
            End;
        End;
        2:
        Begin
            v_3 := FLimit - FCursor;
            Repeat
                If (Not (OutGroupingBk(g_AEIOU, 97, 252))) Then
                Begin
                    goto lab2;
                End;
                Break;
lab2:
                If FCursor > FBkLimit Then
                Begin
                    goto lab0;
                End;
            Until True;
            Begin
                v_4 := FLimit - FCursor;
                Repeat
                    If (Not (InGroupingBk(g_AIOU, 97, 252))) Then
                    Begin
                        goto lab4;
                    End;
                    Break;
lab4:
                    If (Not (InGroupingBk(g_E, 101, 235))) Then
                    Begin
                        goto lab3;
                    End;
                    If FCursor > FBkLimit Then
                    Begin
                        goto lab3;
                    End;
                Until True;
                goto lab0;
lab3:
                FCursor := FLimit - v_4;
            End;
            Begin
                v_5 := FLimit - FCursor;
                If (FCursor <= FBkLimit) Then
                Begin
                    goto lab5;
                End;
                Dec(FCursor);
                If (Not (InGroupingBk(g_AIOU, 97, 252))) Then
                Begin
                    goto lab5;
                End;
                If (Not (OutGroupingBk(g_AEIOU, 97, 252))) Then
                Begin
                    goto lab5;
                End;
                goto lab0;
lab5:
                FCursor := FLimit - v_5;
            End;
            FCursor := FLimit - v_3;
            S_ch := SliceTo();
            Begin
                C := FCursor;
                insert(FCursor, FCursor, S_ch);
                FCursor := C;
            End;
        End;
        3:
        Begin
            SliceFrom('e'#235'e');
        End;
        4:
        Begin
            SliceFrom('iee');
        End;
    End;
lab0:
    FCursor := FLimit - v_1;
    Result := True;
End;

Function TDutchStemmer.r_Step_1c : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
    v_3 : Integer;
    v_4 : Integer;
    AmongVar : Integer;
Label
    lab0,
    lab1,
    lab2,
    lab3;
Begin
    FKet := FCursor;
    AmongVar := FindAmongBk(a_8, 2);
    If (AmongVar = 0) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    FBra := FCursor;
    If I_p1 > FCursor Then
    Begin
        Begin Result := False; Exit; End;
    End;
    If (Not r_C) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    Case AmongVar Of
        1:
        Begin
            Begin
                v_1 := FLimit - FCursor;
                If (Not (EqSBk('n'))) Then
                Begin
                    goto lab0;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab0;
                End;
                Begin Result := False; Exit; End;
lab0:
                FCursor := FLimit - v_1;
            End;
            Repeat
                v_2 := FLimit - FCursor;
                If (Not (EqSBk('in'))) Then
                Begin
                    goto lab1;
                End;
                If FCursor > FBkLimit Then
                Begin
                    goto lab1;
                End;
                SliceFrom('n');
                Break;
lab1:
                FCursor := FLimit - v_2;
                SliceDel;
            Until True;
        End;
        2:
        Begin
            Begin
                v_3 := FLimit - FCursor;
                If (Not (EqSBk('h'))) Then
                Begin
                    goto lab2;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab2;
                End;
                Begin Result := False; Exit; End;
lab2:
                FCursor := FLimit - v_3;
            End;
            Begin
                v_4 := FLimit - FCursor;
                If (Not (EqSBk('en'))) Then
                Begin
                    goto lab3;
                End;
                If FCursor > FBkLimit Then
                Begin
                    goto lab3;
                End;
                Begin Result := False; Exit; End;
lab3:
                FCursor := FLimit - v_4;
            End;
            SliceDel;
        End;
    End;
    Result := True;
End;

Function TDutchStemmer.r_measure : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
    v_3 : Integer;
    v_4 : Integer;
    v_5 : Integer;
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
    lab10;
Begin
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_1 := FCursor;
lab1:
    Begin
        If (Not (OutGrouping(g_v, 97, 252))) Then
        Begin
            goto lab2;
        End;
        goto lab1;
lab2:
    End;
    Begin
        v_2 := 1;
lab3:
        Begin
            v_3 := FCursor;
            Repeat
                If (Not (EqS('ij'))) Then
                Begin
                    goto lab5;
                End;
                Break;
lab5:
                If (Not (InGrouping(g_v, 97, 252))) Then
                Begin
                    goto lab4;
                End;
            Until True;
            Dec(v_2);
            goto lab3;
lab4:
            FCursor := v_3;
        End;
        If (v_2 > 0) Then
        Begin
            goto lab0;
        End;
    End;
    If (Not (OutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab0;
    End;
    I_p1 := FCursor;
lab6:
    Begin
        If (Not (OutGrouping(g_v, 97, 252))) Then
        Begin
            goto lab7;
        End;
        goto lab6;
lab7:
    End;
    Begin
        v_4 := 1;
lab8:
        Begin
            v_5 := FCursor;
            Repeat
                If (Not (EqS('ij'))) Then
                Begin
                    goto lab10;
                End;
                Break;
lab10:
                If (Not (InGrouping(g_v, 97, 252))) Then
                Begin
                    goto lab9;
                End;
            Until True;
            Dec(v_4);
            goto lab8;
lab9:
            FCursor := v_5;
        End;
        If (v_4 > 0) Then
        Begin
            goto lab0;
        End;
    End;
    If (Not (OutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab0;
    End;
    I_p2 := FCursor;
lab0:
    FCursor := v_1;
    Result := True;
End;

Function TDutchStemmer.stem : Boolean;
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
    v_30 : Integer;
    v_31 : Integer;
    v_32 : Integer;
    v_33 : Integer;
    AmongVar : Integer;
    C : Integer;
    B_GE_removed : Boolean;
    B_stemmed : Boolean;
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
    lab33,
    lab34,
    lab35,
    lab36,
    lab37,
    lab38,
    lab39,
    lab40,
    lab41,
    lab42;
Begin
    B_stemmed := False;
    r_measure;
    FBkLimit := FCursor; FCursor := FLimit;
    v_1 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_1, 8);
    If (AmongVar = 0) Then
    Begin
        goto lab0;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab0;
            End;
            Begin
                v_2 := FLimit - FCursor;
                If (Not (EqSBk('t'))) Then
                Begin
                    goto lab1;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab1;
                End;
                goto lab0;
lab1:
                FCursor := FLimit - v_2;
            End;
            If (Not r_C) Then
            Begin
                goto lab0;
            End;
            SliceDel;
        End;
        3:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab0;
            End;
            SliceFrom('ie');
        End;
        4:
        Begin
            Repeat
                v_3 := FLimit - FCursor;
                v_4 := FLimit - FCursor;
                If (Not (EqSBk('ar'))) Then
                Begin
                    goto lab2;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab2;
                End;
                If (Not r_C) Then
                Begin
                    goto lab2;
                End;
                FCursor := FLimit - v_4;
                SliceDel;
                r_lengthen_V;
                Break;
lab2:
                FCursor := FLimit - v_3;
                v_5 := FLimit - FCursor;
                If (Not (EqSBk('er'))) Then
                Begin
                    goto lab3;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab3;
                End;
                If (Not r_C) Then
                Begin
                    goto lab3;
                End;
                FCursor := FLimit - v_5;
                SliceDel;
                Break;
lab3:
                FCursor := FLimit - v_3;
                If I_p1 > FCursor Then
                Begin
                    goto lab0;
                End;
                If (Not r_C) Then
                Begin
                    goto lab0;
                End;
                SliceFrom('e');
            Until True;
        End;
        5:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab0;
            End;
            SliceFrom(#233);
        End;
        6:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab0;
            End;
            If (Not r_V) Then
            Begin
                goto lab0;
            End;
            SliceFrom('au');
        End;
        7:
        Begin
            Repeat
                v_6 := FLimit - FCursor;
                If (Not (EqSBk('hed'))) Then
                Begin
                    goto lab4;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab4;
                End;
                FBra := FCursor;
                SliceFrom('heid');
                Break;
lab4:
                FCursor := FLimit - v_6;
                If (Not (EqSBk('nd'))) Then
                Begin
                    goto lab5;
                End;
                SliceDel;
                Break;
lab5:
                FCursor := FLimit - v_6;
                If (Not (EqSBk('d'))) Then
                Begin
                    goto lab6;
                End;
                If I_p1 > FCursor Then
                Begin
                    goto lab6;
                End;
                If (Not r_C) Then
                Begin
                    goto lab6;
                End;
                FBra := FCursor;
                SliceDel;
                Break;
lab6:
                FCursor := FLimit - v_6;
                Repeat
                    If (Not (EqSBk('i'))) Then
                    Begin
                        goto lab8;
                    End;
                    Break;
lab8:
                    If (Not (EqSBk('j'))) Then
                    Begin
                        goto lab7;
                    End;
                Until True;
                If (Not r_V) Then
                Begin
                    goto lab7;
                End;
                SliceDel;
                Break;
lab7:
                FCursor := FLimit - v_6;
                If I_p1 > FCursor Then
                Begin
                    goto lab0;
                End;
                If (Not r_C) Then
                Begin
                    goto lab0;
                End;
                SliceDel;
                r_lengthen_V;
            Until True;
        End;
        8:
        Begin
            SliceFrom('nd');
        End;
    End;
    B_stemmed := True;
lab0:
    FCursor := FLimit - v_1;
    v_7 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_2, 11);
    If (AmongVar = 0) Then
    Begin
        goto lab9;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            Repeat
                v_8 := FLimit - FCursor;
                If (Not (EqSBk('''t'))) Then
                Begin
                    goto lab10;
                End;
                FBra := FCursor;
                SliceDel;
                Break;
lab10:
                FCursor := FLimit - v_8;
                If (Not (EqSBk('et'))) Then
                Begin
                    goto lab11;
                End;
                FBra := FCursor;
                If I_p1 > FCursor Then
                Begin
                    goto lab11;
                End;
                If (Not r_C) Then
                Begin
                    goto lab11;
                End;
                SliceDel;
                Break;
lab11:
                FCursor := FLimit - v_8;
                If (Not (EqSBk('rnt'))) Then
                Begin
                    goto lab12;
                End;
                FBra := FCursor;
                SliceFrom('rn');
                Break;
lab12:
                FCursor := FLimit - v_8;
                If (Not (EqSBk('t'))) Then
                Begin
                    goto lab13;
                End;
                FBra := FCursor;
                If I_p1 > FCursor Then
                Begin
                    goto lab13;
                End;
                v_9 := FLimit - FCursor;
                If (FCursor <= FBkLimit) Then
                Begin
                    goto lab13;
                End;
                Dec(FCursor);
                Repeat
                    If (Not (InGroupingBk(g_v, 97, 252))) Then
                    Begin
                        goto lab14;
                    End;
                    Break;
lab14:
                    If (Not (EqSBk('ij'))) Then
                    Begin
                        goto lab13;
                    End;
                Until True;
                FCursor := FLimit - v_9;
                SliceDel;
                Break;
lab13:
                FCursor := FLimit - v_8;
                If (Not (EqSBk('ink'))) Then
                Begin
                    goto lab15;
                End;
                FBra := FCursor;
                SliceFrom('ing');
                Break;
lab15:
                FCursor := FLimit - v_8;
                If (Not (EqSBk('mp'))) Then
                Begin
                    goto lab16;
                End;
                FBra := FCursor;
                SliceFrom('m');
                Break;
lab16:
                FCursor := FLimit - v_8;
                If (Not (EqSBk(''''))) Then
                Begin
                    goto lab17;
                End;
                FBra := FCursor;
                If I_p1 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
                Break;
lab17:
                FCursor := FLimit - v_8;
                FBra := FCursor;
                If I_p1 > FCursor Then
                Begin
                    goto lab9;
                End;
                If (Not r_C) Then
                Begin
                    goto lab9;
                End;
                SliceDel;
            Until True;
        End;
        2:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('g');
        End;
        3:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('lijk');
        End;
        4:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('isch');
        End;
        5:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            If (Not r_C) Then
            Begin
                goto lab9;
            End;
            SliceDel;
        End;
        6:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('t');
        End;
        7:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('s');
        End;
        8:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceFrom('r');
        End;
        9:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            SliceDel;
            insert(FCursor, FCursor, 'l');
            r_lengthen_V;
        End;
        10:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            If (Not r_C) Then
            Begin
                goto lab9;
            End;
            SliceDel;
            insert(FCursor, FCursor, 'en');
            r_lengthen_V;
        End;
        11:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab9;
            End;
            If (Not r_C) Then
            Begin
                goto lab9;
            End;
            SliceFrom('ief');
        End;
    End;
    B_stemmed := True;
lab9:
    FCursor := FLimit - v_7;
    v_10 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_3, 14);
    If (AmongVar = 0) Then
    Begin
        goto lab18;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            SliceFrom('eer');
        End;
        2:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            SliceDel;
            r_lengthen_V;
        End;
        3:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            SliceDel;
        End;
        4:
        Begin
            SliceFrom('r');
        End;
        5:
        Begin
            Repeat
                v_11 := FLimit - FCursor;
                If (Not (EqSBk('ild'))) Then
                Begin
                    goto lab19;
                End;
                SliceFrom('er');
                Break;
lab19:
                FCursor := FLimit - v_11;
                If I_p1 > FCursor Then
                Begin
                    goto lab18;
                End;
                SliceDel;
                r_lengthen_V;
            Until True;
        End;
        6:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            If (Not r_C) Then
            Begin
                goto lab18;
            End;
            SliceFrom('aar');
        End;
        7:
        Begin
            If I_p2 > FCursor Then
            Begin
                goto lab18;
            End;
            SliceDel;
            insert(FCursor, FCursor, 'f');
            r_lengthen_V;
        End;
        8:
        Begin
            If I_p2 > FCursor Then
            Begin
                goto lab18;
            End;
            SliceDel;
            insert(FCursor, FCursor, 'g');
            r_lengthen_V;
        End;
        9:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            If (Not r_C) Then
            Begin
                goto lab18;
            End;
            SliceFrom('t');
        End;
        10:
        Begin
            If I_p1 > FCursor Then
            Begin
                goto lab18;
            End;
            If (Not r_C) Then
            Begin
                goto lab18;
            End;
            SliceFrom('d');
        End;
    End;
    B_stemmed := True;
lab18:
    FCursor := FLimit - v_10;
    v_12 := FLimit - FCursor;
    Repeat
        v_13 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_4, 16);
        If (AmongVar = 0) Then
        Begin
            goto lab21;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                SliceFrom('ie');
            End;
            2:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                SliceFrom('eer');
            End;
            3:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                SliceDel;
            End;
            4:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                If (Not r_V) Then
                Begin
                    goto lab21;
                End;
                SliceFrom('n');
            End;
            5:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                If (Not r_V) Then
                Begin
                    goto lab21;
                End;
                SliceFrom('l');
            End;
            6:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                If (Not r_V) Then
                Begin
                    goto lab21;
                End;
                SliceFrom('r');
            End;
            7:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                SliceFrom('teer');
            End;
            8:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                SliceFrom('lijk');
            End;
            9:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab21;
                End;
                If (Not r_C) Then
                Begin
                    goto lab21;
                End;
                SliceDel;
                r_lengthen_V;
            End;
        End;
        Break;
lab21:
        FCursor := FLimit - v_13;
        FKet := FCursor;
        If (FindAmongBk(a_5, 3) = 0) Then
        Begin
            goto lab20;
        End;
        FBra := FCursor;
        If I_p1 > FCursor Then
        Begin
            goto lab20;
        End;
        Begin
            v_14 := FLimit - FCursor;
            If (Not (EqSBk('inn'))) Then
            Begin
                goto lab22;
            End;
            If FCursor > FBkLimit Then
            Begin
                goto lab22;
            End;
            goto lab20;
lab22:
            FCursor := FLimit - v_14;
        End;
        If (Not r_C) Then
        Begin
            goto lab20;
        End;
        SliceDel;
        r_lengthen_V;
    Until True;
    B_stemmed := True;
lab20:
    FCursor := FLimit - v_12;
    FCursor := FBkLimit;
    B_GE_removed := False;
    v_15 := FCursor;
    v_16 := FCursor;
    FBra := FCursor;
    If (Not (EqS('ge'))) Then
    Begin
        goto lab23;
    End;
    FKet := FCursor;
    v_17 := FCursor;
    Begin
        C := FCursor + 3;
        If (C > FLimit) Then
        Begin
            goto lab23;
        End;
        FCursor := C;
    End;
    FCursor := v_17;
    v_18 := FCursor;
    While True Do
    Begin
        v_19 := FCursor;
        Repeat
            If (Not (EqS('ij'))) Then
            Begin
                goto lab25;
            End;
            Break;
lab25:
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab24;
            End;
        Until True;
        Break;
lab24:
        FCursor := v_19;
        If (FCursor >= FLimit) Then
        Begin
            goto lab23;
        End;
        Inc(FCursor);
    End;
lab26:
    Begin
        v_20 := FCursor;
        Repeat
            If (Not (EqS('ij'))) Then
            Begin
                goto lab28;
            End;
            Break;
lab28:
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab27;
            End;
        Until True;
        goto lab26;
lab27:
        FCursor := v_20;
    End;
    If FCursor >= FLimit Then
    Begin
        goto lab23;
    End;
    FCursor := v_18;
    AmongVar := FindAmong(a_9, 6);
    Case AmongVar Of
        1:
        Begin
            goto lab23;
        End;
    End;
    B_GE_removed := True;
    SliceDel;
    v_21 := FCursor;
    FBra := FCursor;
    AmongVar := FindAmong(a_10, 2);
    If (AmongVar = 0) Then
    Begin
        goto lab29;
    End;
    FKet := FCursor;
    Case AmongVar Of
        1:
        Begin
            SliceFrom('e');
        End;
        2:
        Begin
            SliceFrom('i');
        End;
    End;
lab29:
    FCursor := v_21;
    FCursor := v_16;
    r_measure;
lab23:
    FCursor := v_15;
    FBkLimit := FCursor; FCursor := FLimit;
    v_22 := FLimit - FCursor;
    If (Not (B_GE_removed)) Then
    Begin
        goto lab30;
    End;
    B_stemmed := True;
    If (Not r_Step_1c) Then
    Begin
        goto lab30;
    End;
lab30:
    FCursor := FLimit - v_22;
    FCursor := FBkLimit;
    B_GE_removed := False;
    v_23 := FCursor;
    v_24 := FCursor;
    If (FCursor >= FLimit) Then
    Begin
        goto lab31;
    End;
    Inc(FCursor);
    While True Do
    Begin
        FBra := FCursor;
        If (Not (EqS('ge'))) Then
        Begin
            goto lab32;
        End;
        FKet := FCursor;
        Break;
lab32:
        If (FCursor >= FLimit) Then
        Begin
            goto lab31;
        End;
        Inc(FCursor);
    End;
    v_25 := FCursor;
    Begin
        C := FCursor + 3;
        If (C > FLimit) Then
        Begin
            goto lab31;
        End;
        FCursor := C;
    End;
    FCursor := v_25;
    v_26 := FCursor;
    While True Do
    Begin
        v_27 := FCursor;
        Repeat
            If (Not (EqS('ij'))) Then
            Begin
                goto lab34;
            End;
            Break;
lab34:
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab33;
            End;
        Until True;
        Break;
lab33:
        FCursor := v_27;
        If (FCursor >= FLimit) Then
        Begin
            goto lab31;
        End;
        Inc(FCursor);
    End;
lab35:
    Begin
        v_28 := FCursor;
        Repeat
            If (Not (EqS('ij'))) Then
            Begin
                goto lab37;
            End;
            Break;
lab37:
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab36;
            End;
        Until True;
        goto lab35;
lab36:
        FCursor := v_28;
    End;
    If FCursor >= FLimit Then
    Begin
        goto lab31;
    End;
    FCursor := v_26;
    B_GE_removed := True;
    SliceDel;
    v_29 := FCursor;
    FBra := FCursor;
    AmongVar := FindAmong(a_11, 2);
    If (AmongVar = 0) Then
    Begin
        goto lab38;
    End;
    FKet := FCursor;
    Case AmongVar Of
        1:
        Begin
            SliceFrom('e');
        End;
        2:
        Begin
            SliceFrom('i');
        End;
    End;
lab38:
    FCursor := v_29;
    FCursor := v_24;
    r_measure;
lab31:
    FCursor := v_23;
    FBkLimit := FCursor; FCursor := FLimit;
    v_30 := FLimit - FCursor;
    If (Not (B_GE_removed)) Then
    Begin
        goto lab39;
    End;
    B_stemmed := True;
    If (Not r_Step_1c) Then
    Begin
        goto lab39;
    End;
lab39:
    FCursor := FLimit - v_30;
    FCursor := FBkLimit;
    FBkLimit := FCursor; FCursor := FLimit;
    v_31 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_6, 3);
    If (AmongVar = 0) Then
    Begin
        goto lab40;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            SliceFrom('k');
        End;
        2:
        Begin
            SliceFrom('f');
        End;
        3:
        Begin
            SliceFrom('p');
        End;
    End;
    B_stemmed := True;
lab40:
    FCursor := FLimit - v_31;
    v_32 := FLimit - FCursor;
    If (Not (B_stemmed)) Then
    Begin
        goto lab41;
    End;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_7, 22);
    If (AmongVar = 0) Then
    Begin
        goto lab41;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            SliceFrom('b');
        End;
        2:
        Begin
            SliceFrom('c');
        End;
        3:
        Begin
            SliceFrom('d');
        End;
        4:
        Begin
            SliceFrom('f');
        End;
        5:
        Begin
            SliceFrom('g');
        End;
        6:
        Begin
            SliceFrom('h');
        End;
        7:
        Begin
            SliceFrom('j');
        End;
        8:
        Begin
            SliceFrom('k');
        End;
        9:
        Begin
            SliceFrom('l');
        End;
        10:
        Begin
            SliceFrom('m');
        End;
        11:
        Begin
            Begin
                v_33 := FLimit - FCursor;
                If (Not (EqSBk('i'))) Then
                Begin
                    goto lab42;
                End;
                If FCursor > FBkLimit Then
                Begin
                    goto lab42;
                End;
                goto lab41;
lab42:
                FCursor := FLimit - v_33;
            End;
            SliceFrom('n');
        End;
        12:
        Begin
            SliceFrom('p');
        End;
        13:
        Begin
            SliceFrom('q');
        End;
        14:
        Begin
            SliceFrom('r');
        End;
        15:
        Begin
            SliceFrom('s');
        End;
        16:
        Begin
            SliceFrom('t');
        End;
        17:
        Begin
            SliceFrom('v');
        End;
        18:
        Begin
            SliceFrom('w');
        End;
        19:
        Begin
            SliceFrom('x');
        End;
        20:
        Begin
            SliceFrom('z');
        End;
    End;
lab41:
    FCursor := FLimit - v_32;
    FCursor := FBkLimit;
    Result := True;
End;

End.
