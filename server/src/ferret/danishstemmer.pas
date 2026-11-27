// Generated from danish.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit DanishStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TDanishStemmer = Class(TSnowballProgram)
    private
        I_p1 : Integer;
    private
        a_0 : Array Of TAmong;
        a_1 : Array Of TAmong;
        a_2 : Array Of TAmong;
    public
        Constructor Create;
        Function stem : Boolean; Override;
    private
        Function r_consonant_pair : Boolean;
End;

Implementation

Const
    g_undouble_c : Array [0..2] Of Char = (
        Chr(53),
        Chr(94),
        Chr(7)
    );

Const
    g_v : Array [0..18] Of Char = (
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
        Chr(0),
        Chr(48),
        Chr(0),
        Chr(128)
    );

Const
    g_s_ending : Array [0..23] Of Char = (
        Chr(1),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(0),
        Chr(188),
        Chr(251),
        Chr(171),
        Chr(12),
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
        Chr(64)
    );

Constructor TDanishStemmer.Create;
Begin
    SetLength(a_0, 32);
        a_0[0].Str  := 'hed';
        a_0[0].Index := -1;
        a_0[0].Result := 1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'ethed';
        a_0[1].Index := 0;
        a_0[1].Result := 1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'ered';
        a_0[2].Index := -1;
        a_0[2].Result := 1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'e';
        a_0[3].Index := -1;
        a_0[3].Result := 1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'erede';
        a_0[4].Index := 3;
        a_0[4].Result := 1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'ende';
        a_0[5].Index := 3;
        a_0[5].Result := 1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'erende';
        a_0[6].Index := 5;
        a_0[6].Result := 1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'ene';
        a_0[7].Index := 3;
        a_0[7].Result := 1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'erne';
        a_0[8].Index := 3;
        a_0[8].Result := 1;
        a_0[8].Method := nil;

        a_0[9].Str  := 'ere';
        a_0[9].Index := 3;
        a_0[9].Result := 1;
        a_0[9].Method := nil;

        a_0[10].Str  := 'en';
        a_0[10].Index := -1;
        a_0[10].Result := 1;
        a_0[10].Method := nil;

        a_0[11].Str  := 'heden';
        a_0[11].Index := 10;
        a_0[11].Result := 1;
        a_0[11].Method := nil;

        a_0[12].Str  := 'eren';
        a_0[12].Index := 10;
        a_0[12].Result := 1;
        a_0[12].Method := nil;

        a_0[13].Str  := 'er';
        a_0[13].Index := -1;
        a_0[13].Result := 1;
        a_0[13].Method := nil;

        a_0[14].Str  := 'heder';
        a_0[14].Index := 13;
        a_0[14].Result := 1;
        a_0[14].Method := nil;

        a_0[15].Str  := 'erer';
        a_0[15].Index := 13;
        a_0[15].Result := 1;
        a_0[15].Method := nil;

        a_0[16].Str  := 's';
        a_0[16].Index := -1;
        a_0[16].Result := 2;
        a_0[16].Method := nil;

        a_0[17].Str  := 'heds';
        a_0[17].Index := 16;
        a_0[17].Result := 1;
        a_0[17].Method := nil;

        a_0[18].Str  := 'es';
        a_0[18].Index := 16;
        a_0[18].Result := 1;
        a_0[18].Method := nil;

        a_0[19].Str  := 'endes';
        a_0[19].Index := 18;
        a_0[19].Result := 1;
        a_0[19].Method := nil;

        a_0[20].Str  := 'erendes';
        a_0[20].Index := 19;
        a_0[20].Result := 1;
        a_0[20].Method := nil;

        a_0[21].Str  := 'enes';
        a_0[21].Index := 18;
        a_0[21].Result := 1;
        a_0[21].Method := nil;

        a_0[22].Str  := 'ernes';
        a_0[22].Index := 18;
        a_0[22].Result := 1;
        a_0[22].Method := nil;

        a_0[23].Str  := 'eres';
        a_0[23].Index := 18;
        a_0[23].Result := 1;
        a_0[23].Method := nil;

        a_0[24].Str  := 'ens';
        a_0[24].Index := 16;
        a_0[24].Result := 1;
        a_0[24].Method := nil;

        a_0[25].Str  := 'hedens';
        a_0[25].Index := 24;
        a_0[25].Result := 1;
        a_0[25].Method := nil;

        a_0[26].Str  := 'erens';
        a_0[26].Index := 24;
        a_0[26].Result := 1;
        a_0[26].Method := nil;

        a_0[27].Str  := 'ers';
        a_0[27].Index := 16;
        a_0[27].Result := 1;
        a_0[27].Method := nil;

        a_0[28].Str  := 'ets';
        a_0[28].Index := 16;
        a_0[28].Result := 1;
        a_0[28].Method := nil;

        a_0[29].Str  := 'erets';
        a_0[29].Index := 28;
        a_0[29].Result := 1;
        a_0[29].Method := nil;

        a_0[30].Str  := 'et';
        a_0[30].Index := -1;
        a_0[30].Result := 1;
        a_0[30].Method := nil;

        a_0[31].Str  := 'eret';
        a_0[31].Index := 30;
        a_0[31].Result := 1;
        a_0[31].Method := nil;

    SetLength(a_1, 4);
        a_1[0].Str  := 'gd';
        a_1[0].Index := -1;
        a_1[0].Result := -1;
        a_1[0].Method := nil;

        a_1[1].Str  := 'dt';
        a_1[1].Index := -1;
        a_1[1].Result := -1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'gt';
        a_1[2].Index := -1;
        a_1[2].Result := -1;
        a_1[2].Method := nil;

        a_1[3].Str  := 'kt';
        a_1[3].Index := -1;
        a_1[3].Result := -1;
        a_1[3].Method := nil;

    SetLength(a_2, 5);
        a_2[0].Str  := 'ig';
        a_2[0].Index := -1;
        a_2[0].Result := 1;
        a_2[0].Method := nil;

        a_2[1].Str  := 'lig';
        a_2[1].Index := 0;
        a_2[1].Result := 1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'elig';
        a_2[2].Index := 1;
        a_2[2].Result := 1;
        a_2[2].Method := nil;

        a_2[3].Str  := 'els';
        a_2[3].Index := -1;
        a_2[3].Result := 1;
        a_2[3].Method := nil;

        a_2[4].Str  := 'l'#248'st';
        a_2[4].Index := -1;
        a_2[4].Result := 2;
        a_2[4].Method := nil;

End;

Function TDanishStemmer.r_consonant_pair : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
Begin
    v_1 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    v_2 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    If (FindAmongBk(a_1, 4) = 0) Then
    Begin
        FBkLimit := v_2;
        Begin Result := False; Exit; End;
    End;
    FBra := FCursor;
    FBkLimit := v_2;
    FCursor := FLimit - v_1;
    If (FCursor <= FBkLimit) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    Dec(FCursor);
    FBra := FCursor;
    SliceDel;
    Result := True;
End;

Function TDanishStemmer.stem : Boolean;
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
    AmongVar : Integer;
    C : Integer;
    S_ch : AnsiString;
Label
    lab0,
    lab1,
    lab2,
    lab3,
    lab4,
    lab5,
    lab6,
    lab7;
Begin
    I_p1 := FLimit;
    v_1 := FCursor;
    Repeat
        v_2 := FCursor;
        While True Do
        Begin
            If (Not (EqS(''''))) Then
            Begin
                goto lab2;
            End;
            Break;
lab2:
            If (FCursor >= FLimit) Then
            Begin
                goto lab1;
            End;
            Inc(FCursor);
        End;
        Break;
lab1:
        FCursor := v_2;
        If (Not (GoOutGrouping(g_v, 97, 248))) Then
        Begin
            goto lab0;
        End;
        Inc(FCursor);
        If (Not (GoInGrouping(g_v, 97, 248))) Then
        Begin
            goto lab0;
        End;
        Inc(FCursor);
    Until True;
    I_p1 := FCursor;
lab0:
    FCursor := v_1;
    v_3 := FCursor;
    Begin
        C := FCursor + 3;
        If (C > FLimit) Then
        Begin
            Begin Result := False; Exit; End;
        End;
        FCursor := C;
    End;
    If I_p1 >= FCursor Then
    Begin
        goto lab3;
    End;
    I_p1 := FCursor;
lab3:
    FCursor := v_3;
    FBkLimit := FCursor; FCursor := FLimit;
    v_4 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab4;
    End;
    v_5 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_0, 32);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_5;
        goto lab4;
    End;
    FBra := FCursor;
    FBkLimit := v_5;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            If (Not (InGroupingBk(g_s_ending, 39, 229))) Then
            Begin
                goto lab4;
            End;
            SliceDel;
        End;
    End;
lab4:
    FCursor := FLimit - v_4;
    v_6 := FLimit - FCursor;
    r_consonant_pair();
    FCursor := FLimit - v_6;
    v_7 := FLimit - FCursor;
    v_8 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (EqSBk('st'))) Then
    Begin
        goto lab6;
    End;
    FBra := FCursor;
    If (Not (EqSBk('ig'))) Then
    Begin
        goto lab6;
    End;
    SliceDel;
lab6:
    FCursor := FLimit - v_8;
    If (FCursor < I_p1) Then
    Begin
        goto lab5;
    End;
    v_9 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_2, 5);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_9;
        goto lab5;
    End;
    FBra := FCursor;
    FBkLimit := v_9;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
            v_10 := FLimit - FCursor;
            r_consonant_pair();
            FCursor := FLimit - v_10;
        End;
        2:
        Begin
            SliceFrom('l'#248's');
        End;
    End;
lab5:
    FCursor := FLimit - v_7;
    v_11 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab7;
    End;
    v_12 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    If (Not (InGroupingBk(g_undouble_c, 98, 116))) Then
    Begin
        FBkLimit := v_12;
        goto lab7;
    End;
    FBra := FCursor;
    S_ch := SliceTo();
    FBkLimit := v_12;
    If (Not (EqSBk(S_ch))) Then
    Begin
        goto lab7;
    End;
    SliceDel;
lab7:
    FCursor := FLimit - v_11;
    FKet := FCursor;
    If (Not (EqSBk(''''))) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    FBra := FCursor;
    SliceDel;
    FCursor := FBkLimit;
    Result := True;
End;

End.
