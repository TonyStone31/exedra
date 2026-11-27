// Generated from norwegian.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit NorwegianStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TNorwegianStemmer = Class(TSnowballProgram)
    private
        a_0 : Array Of TAmong;
        a_1 : Array Of TAmong;
        a_2 : Array Of TAmong;
        a_3 : Array Of TAmong;
    public
        Constructor Create;
        Function stem : Boolean; Override;
End;

Implementation

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
        Chr(2),
        Chr(142)
    );

Const
    g_s_ending : Array [0..3] Of Char = (
        Chr(119),
        Chr(125),
        Chr(148),
        Chr(1)
    );

Constructor TNorwegianStemmer.Create;
Begin
    SetLength(a_0, 15);
        a_0[0].Str  := '';
        a_0[0].Index := -1;
        a_0[0].Result := 1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'ind';
        a_0[1].Index := 0;
        a_0[1].Result := -1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'kk';
        a_0[2].Index := 0;
        a_0[2].Result := -1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'nk';
        a_0[3].Index := 0;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'amm';
        a_0[4].Index := 0;
        a_0[4].Result := -1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'omm';
        a_0[5].Index := 0;
        a_0[5].Result := -1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'kap';
        a_0[6].Index := 0;
        a_0[6].Result := -1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'skap';
        a_0[7].Index := 6;
        a_0[7].Result := 1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'pp';
        a_0[8].Index := 0;
        a_0[8].Result := -1;
        a_0[8].Method := nil;

        a_0[9].Str  := 'lt';
        a_0[9].Index := 0;
        a_0[9].Result := -1;
        a_0[9].Method := nil;

        a_0[10].Str  := 'ast';
        a_0[10].Index := 0;
        a_0[10].Result := -1;
        a_0[10].Method := nil;

        a_0[11].Str  := #248'st';
        a_0[11].Index := 0;
        a_0[11].Result := -1;
        a_0[11].Method := nil;

        a_0[12].Str  := 'v';
        a_0[12].Index := 0;
        a_0[12].Result := -1;
        a_0[12].Method := nil;

        a_0[13].Str  := 'hav';
        a_0[13].Index := 12;
        a_0[13].Result := 1;
        a_0[13].Method := nil;

        a_0[14].Str  := 'giv';
        a_0[14].Index := 12;
        a_0[14].Result := 1;
        a_0[14].Method := nil;

    SetLength(a_1, 29);
        a_1[0].Str  := 'a';
        a_1[0].Index := -1;
        a_1[0].Result := 1;
        a_1[0].Method := nil;

        a_1[1].Str  := 'e';
        a_1[1].Index := -1;
        a_1[1].Result := 1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'ede';
        a_1[2].Index := 1;
        a_1[2].Result := 1;
        a_1[2].Method := nil;

        a_1[3].Str  := 'ande';
        a_1[3].Index := 1;
        a_1[3].Result := 1;
        a_1[3].Method := nil;

        a_1[4].Str  := 'ende';
        a_1[4].Index := 1;
        a_1[4].Result := 1;
        a_1[4].Method := nil;

        a_1[5].Str  := 'ane';
        a_1[5].Index := 1;
        a_1[5].Result := 1;
        a_1[5].Method := nil;

        a_1[6].Str  := 'ene';
        a_1[6].Index := 1;
        a_1[6].Result := 1;
        a_1[6].Method := nil;

        a_1[7].Str  := 'hetene';
        a_1[7].Index := 6;
        a_1[7].Result := 1;
        a_1[7].Method := nil;

        a_1[8].Str  := 'erte';
        a_1[8].Index := 1;
        a_1[8].Result := 4;
        a_1[8].Method := nil;

        a_1[9].Str  := 'en';
        a_1[9].Index := -1;
        a_1[9].Result := 1;
        a_1[9].Method := nil;

        a_1[10].Str  := 'heten';
        a_1[10].Index := 9;
        a_1[10].Result := 1;
        a_1[10].Method := nil;

        a_1[11].Str  := 'ar';
        a_1[11].Index := -1;
        a_1[11].Result := 1;
        a_1[11].Method := nil;

        a_1[12].Str  := 'er';
        a_1[12].Index := -1;
        a_1[12].Result := 1;
        a_1[12].Method := nil;

        a_1[13].Str  := 'heter';
        a_1[13].Index := 12;
        a_1[13].Result := 1;
        a_1[13].Method := nil;

        a_1[14].Str  := 's';
        a_1[14].Index := -1;
        a_1[14].Result := 3;
        a_1[14].Method := nil;

        a_1[15].Str  := 'as';
        a_1[15].Index := 14;
        a_1[15].Result := 1;
        a_1[15].Method := nil;

        a_1[16].Str  := 'es';
        a_1[16].Index := 14;
        a_1[16].Result := 1;
        a_1[16].Method := nil;

        a_1[17].Str  := 'edes';
        a_1[17].Index := 16;
        a_1[17].Result := 1;
        a_1[17].Method := nil;

        a_1[18].Str  := 'endes';
        a_1[18].Index := 16;
        a_1[18].Result := 1;
        a_1[18].Method := nil;

        a_1[19].Str  := 'enes';
        a_1[19].Index := 16;
        a_1[19].Result := 1;
        a_1[19].Method := nil;

        a_1[20].Str  := 'hetenes';
        a_1[20].Index := 19;
        a_1[20].Result := 1;
        a_1[20].Method := nil;

        a_1[21].Str  := 'ens';
        a_1[21].Index := 14;
        a_1[21].Result := 1;
        a_1[21].Method := nil;

        a_1[22].Str  := 'hetens';
        a_1[22].Index := 21;
        a_1[22].Result := 1;
        a_1[22].Method := nil;

        a_1[23].Str  := 'ers';
        a_1[23].Index := 14;
        a_1[23].Result := 2;
        a_1[23].Method := nil;

        a_1[24].Str  := 'ets';
        a_1[24].Index := 14;
        a_1[24].Result := 1;
        a_1[24].Method := nil;

        a_1[25].Str  := 'et';
        a_1[25].Index := -1;
        a_1[25].Result := 1;
        a_1[25].Method := nil;

        a_1[26].Str  := 'het';
        a_1[26].Index := 25;
        a_1[26].Result := 1;
        a_1[26].Method := nil;

        a_1[27].Str  := 'ert';
        a_1[27].Index := -1;
        a_1[27].Result := 4;
        a_1[27].Method := nil;

        a_1[28].Str  := 'ast';
        a_1[28].Index := -1;
        a_1[28].Result := 1;
        a_1[28].Method := nil;

    SetLength(a_2, 2);
        a_2[0].Str  := 'dt';
        a_2[0].Index := -1;
        a_2[0].Result := -1;
        a_2[0].Method := nil;

        a_2[1].Str  := 'vt';
        a_2[1].Index := -1;
        a_2[1].Result := -1;
        a_2[1].Method := nil;

    SetLength(a_3, 11);
        a_3[0].Str  := 'leg';
        a_3[0].Index := -1;
        a_3[0].Result := 1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'eleg';
        a_3[1].Index := 0;
        a_3[1].Result := 1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'ig';
        a_3[2].Index := -1;
        a_3[2].Result := 1;
        a_3[2].Method := nil;

        a_3[3].Str  := 'eig';
        a_3[3].Index := 2;
        a_3[3].Result := 1;
        a_3[3].Method := nil;

        a_3[4].Str  := 'lig';
        a_3[4].Index := 2;
        a_3[4].Result := 1;
        a_3[4].Method := nil;

        a_3[5].Str  := 'elig';
        a_3[5].Index := 4;
        a_3[5].Result := 1;
        a_3[5].Method := nil;

        a_3[6].Str  := 'els';
        a_3[6].Index := -1;
        a_3[6].Result := 1;
        a_3[6].Method := nil;

        a_3[7].Str  := 'lov';
        a_3[7].Index := -1;
        a_3[7].Result := 1;
        a_3[7].Method := nil;

        a_3[8].Str  := 'elov';
        a_3[8].Index := 7;
        a_3[8].Result := 1;
        a_3[8].Method := nil;

        a_3[9].Str  := 'slov';
        a_3[9].Index := 7;
        a_3[9].Result := 1;
        a_3[9].Method := nil;

        a_3[10].Str  := 'hetslov';
        a_3[10].Index := 9;
        a_3[10].Result := 1;
        a_3[10].Method := nil;

End;

Function TNorwegianStemmer.stem : Boolean;
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
    AmongVar : Integer;
    C : Integer;
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
    lab9;
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
    AmongVar := FindAmongBk(a_1, 29);
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
            AmongVar := FindAmongBk(a_0, 15);
            Case AmongVar Of
                1:
                Begin
                    SliceDel;
                End;
            End;
        End;
        3:
        Begin
            Repeat
                v_6 := FLimit - FCursor;
                If (Not (InGroupingBk(g_s_ending, 98, 122))) Then
                Begin
                    goto lab5;
                End;
                Break;
lab5:
                FCursor := FLimit - v_6;
                If (Not (EqSBk('r'))) Then
                Begin
                    goto lab6;
                End;
                If (Not (EqSBk('e'))) Then
                Begin
                    goto lab7;
                End;
                goto lab6;
lab7:
                Break;
lab6:
                FCursor := FLimit - v_6;
                If (Not (EqSBk('k'))) Then
                Begin
                    goto lab4;
                End;
                If (Not (OutGroupingBk(g_v, 97, 248))) Then
                Begin
                    goto lab4;
                End;
            Until True;
            SliceDel;
        End;
        4:
        Begin
            SliceFrom('er');
        End;
    End;
lab4:
    FCursor := FLimit - v_4;
    v_7 := FLimit - FCursor;
    v_8 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab8;
    End;
    v_9 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    If (FindAmongBk(a_2, 2) = 0) Then
    Begin
        FBkLimit := v_9;
        goto lab8;
    End;
    FBra := FCursor;
    FBkLimit := v_9;
    FCursor := FLimit - v_8;
    If (FCursor <= FBkLimit) Then
    Begin
        goto lab8;
    End;
    Dec(FCursor);
    FBra := FCursor;
    SliceDel;
lab8:
    FCursor := FLimit - v_7;
    v_10 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab9;
    End;
    v_11 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    If (FindAmongBk(a_3, 11) = 0) Then
    Begin
        FBkLimit := v_11;
        goto lab9;
    End;
    FBra := FCursor;
    FBkLimit := v_11;
    SliceDel;
lab9:
    FCursor := FLimit - v_10;
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
