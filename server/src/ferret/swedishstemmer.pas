// Generated from swedish.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit SwedishStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TSwedishStemmer = Class(TSnowballProgram)
    private
        a_0 : Array Of TAmong;
        a_1 : Array Of TAmong;
        a_2 : Array Of TAmong;
        a_3 : Array Of TAmong;
    public
        Constructor Create;
        Function stem : Boolean; Override;
    private
        Function r_et_condition : Boolean;
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
        Chr(24),
        Chr(0),
        Chr(32)
    );

Const
    g_s_ending : Array [0..2] Of Char = (
        Chr(119),
        Chr(127),
        Chr(149)
    );

Const
    g_ost_ending : Array [0..1] Of Char = (
        Chr(173),
        Chr(58)
    );

Constructor TSwedishStemmer.Create;
Begin
    SetLength(a_0, 21);
        a_0[0].Str  := 'fab';
        a_0[0].Index := -1;
        a_0[0].Result := -1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'h';
        a_0[1].Index := -1;
        a_0[1].Result := -1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'pak';
        a_0[2].Index := -1;
        a_0[2].Result := -1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'rak';
        a_0[3].Index := -1;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'stak';
        a_0[4].Index := -1;
        a_0[4].Result := -1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'kom';
        a_0[5].Index := -1;
        a_0[5].Result := -1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'iet';
        a_0[6].Index := -1;
        a_0[6].Result := -1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'cit';
        a_0[7].Index := -1;
        a_0[7].Result := -1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'dit';
        a_0[8].Index := -1;
        a_0[8].Result := -1;
        a_0[8].Method := nil;

        a_0[9].Str  := 'alit';
        a_0[9].Index := -1;
        a_0[9].Result := -1;
        a_0[9].Method := nil;

        a_0[10].Str  := 'ilit';
        a_0[10].Index := -1;
        a_0[10].Result := -1;
        a_0[10].Method := nil;

        a_0[11].Str  := 'mit';
        a_0[11].Index := -1;
        a_0[11].Result := -1;
        a_0[11].Method := nil;

        a_0[12].Str  := 'nit';
        a_0[12].Index := -1;
        a_0[12].Result := -1;
        a_0[12].Method := nil;

        a_0[13].Str  := 'pit';
        a_0[13].Index := -1;
        a_0[13].Result := -1;
        a_0[13].Method := nil;

        a_0[14].Str  := 'rit';
        a_0[14].Index := -1;
        a_0[14].Result := -1;
        a_0[14].Method := nil;

        a_0[15].Str  := 'sit';
        a_0[15].Index := -1;
        a_0[15].Result := -1;
        a_0[15].Method := nil;

        a_0[16].Str  := 'tit';
        a_0[16].Index := -1;
        a_0[16].Result := -1;
        a_0[16].Method := nil;

        a_0[17].Str  := 'uit';
        a_0[17].Index := -1;
        a_0[17].Result := -1;
        a_0[17].Method := nil;

        a_0[18].Str  := 'ivit';
        a_0[18].Index := -1;
        a_0[18].Result := -1;
        a_0[18].Method := nil;

        a_0[19].Str  := 'kvit';
        a_0[19].Index := -1;
        a_0[19].Result := -1;
        a_0[19].Method := nil;

        a_0[20].Str  := 'xit';
        a_0[20].Index := -1;
        a_0[20].Result := -1;
        a_0[20].Method := nil;

    SetLength(a_1, 38);
        a_1[0].Str  := 'a';
        a_1[0].Index := -1;
        a_1[0].Result := 1;
        a_1[0].Method := nil;

        a_1[1].Str  := 'arna';
        a_1[1].Index := 0;
        a_1[1].Result := 1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'erna';
        a_1[2].Index := 0;
        a_1[2].Result := 1;
        a_1[2].Method := nil;

        a_1[3].Str  := 'heterna';
        a_1[3].Index := 2;
        a_1[3].Result := 1;
        a_1[3].Method := nil;

        a_1[4].Str  := 'orna';
        a_1[4].Index := 0;
        a_1[4].Result := 1;
        a_1[4].Method := nil;

        a_1[5].Str  := 'ad';
        a_1[5].Index := -1;
        a_1[5].Result := 1;
        a_1[5].Method := nil;

        a_1[6].Str  := 'e';
        a_1[6].Index := -1;
        a_1[6].Result := 1;
        a_1[6].Method := nil;

        a_1[7].Str  := 'ade';
        a_1[7].Index := 6;
        a_1[7].Result := 1;
        a_1[7].Method := nil;

        a_1[8].Str  := 'ande';
        a_1[8].Index := 6;
        a_1[8].Result := 1;
        a_1[8].Method := nil;

        a_1[9].Str  := 'arne';
        a_1[9].Index := 6;
        a_1[9].Result := 1;
        a_1[9].Method := nil;

        a_1[10].Str  := 'are';
        a_1[10].Index := 6;
        a_1[10].Result := 1;
        a_1[10].Method := nil;

        a_1[11].Str  := 'aste';
        a_1[11].Index := 6;
        a_1[11].Result := 1;
        a_1[11].Method := nil;

        a_1[12].Str  := 'en';
        a_1[12].Index := -1;
        a_1[12].Result := 1;
        a_1[12].Method := nil;

        a_1[13].Str  := 'anden';
        a_1[13].Index := 12;
        a_1[13].Result := 1;
        a_1[13].Method := nil;

        a_1[14].Str  := 'aren';
        a_1[14].Index := 12;
        a_1[14].Result := 1;
        a_1[14].Method := nil;

        a_1[15].Str  := 'heten';
        a_1[15].Index := 12;
        a_1[15].Result := 1;
        a_1[15].Method := nil;

        a_1[16].Str  := 'ern';
        a_1[16].Index := -1;
        a_1[16].Result := 1;
        a_1[16].Method := nil;

        a_1[17].Str  := 'ar';
        a_1[17].Index := -1;
        a_1[17].Result := 1;
        a_1[17].Method := nil;

        a_1[18].Str  := 'er';
        a_1[18].Index := -1;
        a_1[18].Result := 1;
        a_1[18].Method := nil;

        a_1[19].Str  := 'heter';
        a_1[19].Index := 18;
        a_1[19].Result := 1;
        a_1[19].Method := nil;

        a_1[20].Str  := 'or';
        a_1[20].Index := -1;
        a_1[20].Result := 1;
        a_1[20].Method := nil;

        a_1[21].Str  := 's';
        a_1[21].Index := -1;
        a_1[21].Result := 2;
        a_1[21].Method := nil;

        a_1[22].Str  := 'as';
        a_1[22].Index := 21;
        a_1[22].Result := 1;
        a_1[22].Method := nil;

        a_1[23].Str  := 'arnas';
        a_1[23].Index := 22;
        a_1[23].Result := 1;
        a_1[23].Method := nil;

        a_1[24].Str  := 'ernas';
        a_1[24].Index := 22;
        a_1[24].Result := 1;
        a_1[24].Method := nil;

        a_1[25].Str  := 'ornas';
        a_1[25].Index := 22;
        a_1[25].Result := 1;
        a_1[25].Method := nil;

        a_1[26].Str  := 'es';
        a_1[26].Index := 21;
        a_1[26].Result := 1;
        a_1[26].Method := nil;

        a_1[27].Str  := 'ades';
        a_1[27].Index := 26;
        a_1[27].Result := 1;
        a_1[27].Method := nil;

        a_1[28].Str  := 'andes';
        a_1[28].Index := 26;
        a_1[28].Result := 1;
        a_1[28].Method := nil;

        a_1[29].Str  := 'ens';
        a_1[29].Index := 21;
        a_1[29].Result := 1;
        a_1[29].Method := nil;

        a_1[30].Str  := 'arens';
        a_1[30].Index := 29;
        a_1[30].Result := 1;
        a_1[30].Method := nil;

        a_1[31].Str  := 'hetens';
        a_1[31].Index := 29;
        a_1[31].Result := 1;
        a_1[31].Method := nil;

        a_1[32].Str  := 'erns';
        a_1[32].Index := 21;
        a_1[32].Result := 1;
        a_1[32].Method := nil;

        a_1[33].Str  := 'at';
        a_1[33].Index := -1;
        a_1[33].Result := 1;
        a_1[33].Method := nil;

        a_1[34].Str  := 'et';
        a_1[34].Index := -1;
        a_1[34].Result := 3;
        a_1[34].Method := nil;

        a_1[35].Str  := 'andet';
        a_1[35].Index := 34;
        a_1[35].Result := 1;
        a_1[35].Method := nil;

        a_1[36].Str  := 'het';
        a_1[36].Index := 34;
        a_1[36].Result := 1;
        a_1[36].Method := nil;

        a_1[37].Str  := 'ast';
        a_1[37].Index := -1;
        a_1[37].Result := 1;
        a_1[37].Method := nil;

    SetLength(a_2, 7);
        a_2[0].Str  := 'dd';
        a_2[0].Index := -1;
        a_2[0].Result := -1;
        a_2[0].Method := nil;

        a_2[1].Str  := 'gd';
        a_2[1].Index := -1;
        a_2[1].Result := -1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'nn';
        a_2[2].Index := -1;
        a_2[2].Result := -1;
        a_2[2].Method := nil;

        a_2[3].Str  := 'dt';
        a_2[3].Index := -1;
        a_2[3].Result := -1;
        a_2[3].Method := nil;

        a_2[4].Str  := 'gt';
        a_2[4].Index := -1;
        a_2[4].Result := -1;
        a_2[4].Method := nil;

        a_2[5].Str  := 'kt';
        a_2[5].Index := -1;
        a_2[5].Result := -1;
        a_2[5].Method := nil;

        a_2[6].Str  := 'tt';
        a_2[6].Index := -1;
        a_2[6].Result := -1;
        a_2[6].Method := nil;

    SetLength(a_3, 5);
        a_3[0].Str  := 'ig';
        a_3[0].Index := -1;
        a_3[0].Result := 1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'lig';
        a_3[1].Index := 0;
        a_3[1].Result := 1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'els';
        a_3[2].Index := -1;
        a_3[2].Result := 1;
        a_3[2].Method := nil;

        a_3[3].Str  := 'fullt';
        a_3[3].Index := -1;
        a_3[3].Result := 3;
        a_3[3].Method := nil;

        a_3[4].Str  := #246'st';
        a_3[4].Index := -1;
        a_3[4].Result := 2;
        a_3[4].Method := nil;

End;

Function TSwedishStemmer.r_et_condition : Boolean;
Var
    v_1 : Integer;
    v_2 : Integer;
Label
    lab0;
Begin
    v_1 := FLimit - FCursor;
    If (Not (OutGroupingBk(g_v, 97, 246))) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    If (Not (InGroupingBk(g_v, 97, 246))) Then
    Begin
        Begin Result := False; Exit; End;
    End;
    If FCursor <= FBkLimit Then
    Begin
        Begin Result := False; Exit; End;
    End;
    FCursor := FLimit - v_1;
    Begin
        v_2 := FLimit - FCursor;
        If (FindAmongBk(a_0, 21) = 0) Then
        Begin
            goto lab0;
        End;
        Begin Result := False; Exit; End;
lab0:
        FCursor := FLimit - v_2;
    End;
    Result := True;
End;

Function TSwedishStemmer.stem : Boolean;
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
    AmongVar : Integer;
    C : Integer;
    I_x : Integer;
    I_p1 : Integer;
Label
    lab0,
    lab1,
    lab2,
    lab3,
    lab4,
    lab5;
Begin
    v_1 := FCursor;
    I_p1 := FLimit;
    v_2 := FCursor;
    Begin
        C := FCursor + 3;
        If (C > FLimit) Then
        Begin
            goto lab0;
        End;
        FCursor := C;
    End;
    I_x := FCursor;
    FCursor := v_2;
    If (Not (GoOutGrouping(g_v, 97, 246))) Then
    Begin
        goto lab0;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 246))) Then
    Begin
        goto lab0;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If I_p1 >= I_x Then
    Begin
        goto lab1;
    End;
    I_p1 := I_x;
lab1:
lab0:
    FCursor := v_1;
    FBkLimit := FCursor; FCursor := FLimit;
    v_3 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab2;
    End;
    v_4 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_1, 38);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_4;
        goto lab2;
    End;
    FBra := FCursor;
    FBkLimit := v_4;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            Repeat
                v_5 := FLimit - FCursor;
                If (Not (EqSBk('et'))) Then
                Begin
                    goto lab3;
                End;
                If (Not r_et_condition) Then
                Begin
                    goto lab3;
                End;
                FBra := FCursor;
                Break;
lab3:
                FCursor := FLimit - v_5;
                If (Not (InGroupingBk(g_s_ending, 98, 121))) Then
                Begin
                    goto lab2;
                End;
            Until True;
            SliceDel;
        End;
        3:
        Begin
            If (Not r_et_condition) Then
            Begin
                goto lab2;
            End;
            SliceDel;
        End;
    End;
lab2:
    FCursor := FLimit - v_3;
    v_6 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab4;
    End;
    v_7 := FBkLimit;
    FBkLimit := I_p1;
    v_8 := FLimit - FCursor;
    If (FindAmongBk(a_2, 7) = 0) Then
    Begin
        FBkLimit := v_7;
        goto lab4;
    End;
    FCursor := FLimit - v_8;
    FKet := FCursor;
    If (FCursor <= FBkLimit) Then
    Begin
        FBkLimit := v_7;
        goto lab4;
    End;
    Dec(FCursor);
    FBra := FCursor;
    SliceDel;
    FBkLimit := v_7;
lab4:
    FCursor := FLimit - v_6;
    v_9 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab5;
    End;
    v_10 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_3, 5);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_10;
        goto lab5;
    End;
    FBra := FCursor;
    FBkLimit := v_10;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            If (Not (InGroupingBk(g_ost_ending, 105, 118))) Then
            Begin
                goto lab5;
            End;
            SliceFrom(#246's');
        End;
        3:
        Begin
            SliceFrom('full');
        End;
    End;
lab5:
    FCursor := FLimit - v_9;
    FCursor := FBkLimit;
    Result := True;
End;

End.
