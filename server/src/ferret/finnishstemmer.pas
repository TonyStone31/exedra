// Generated from finnish.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit FinnishStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TFinnishStemmer = Class(TSnowballProgram)
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
    public
        Constructor Create;
        Function stem : Boolean; Override;
    private
        Function r_O_ : Boolean;
        Function r_A_ : Boolean;
        Function r_U : Boolean;
        Function r_O : Boolean;
        Function r_I : Boolean;
        Function r_E : Boolean;
        Function r_A : Boolean;
        Function r_VI : Boolean;
        Function r_LV : Boolean;
End;

Implementation

Const
    g_AEI : Array [0..16] Of Char = (
        Chr(17),
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
        Chr(8)
    );

Const
    g_C : Array [0..3] Of Char = (
        Chr(119),
        Chr(223),
        Chr(119),
        Chr(1)
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
        Chr(8),
        Chr(0),
        Chr(32)
    );

Const
    g_particle_end : Array [0..18] Of Char = (
        Chr(17),
        Chr(97),
        Chr(24),
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
        Chr(8),
        Chr(0),
        Chr(32)
    );

Constructor TFinnishStemmer.Create;
Begin
    SetLength(a_0, 10);
        a_0[0].Str  := 'pa';
        a_0[0].Index := -1;
        a_0[0].Result := 1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'sti';
        a_0[1].Index := -1;
        a_0[1].Result := 2;
        a_0[1].Method := nil;

        a_0[2].Str  := 'kaan';
        a_0[2].Index := -1;
        a_0[2].Result := 1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'han';
        a_0[3].Index := -1;
        a_0[3].Result := 1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'kin';
        a_0[4].Index := -1;
        a_0[4].Result := 1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'h'#228'n';
        a_0[5].Index := -1;
        a_0[5].Result := 1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'k'#228#228'n';
        a_0[6].Index := -1;
        a_0[6].Result := 1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'ko';
        a_0[7].Index := -1;
        a_0[7].Result := 1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'p'#228;
        a_0[8].Index := -1;
        a_0[8].Result := 1;
        a_0[8].Method := nil;

        a_0[9].Str  := 'k'#246;
        a_0[9].Index := -1;
        a_0[9].Result := 1;
        a_0[9].Method := nil;

    SetLength(a_1, 6);
        a_1[0].Str  := 'lla';
        a_1[0].Index := -1;
        a_1[0].Result := -1;
        a_1[0].Method := nil;

        a_1[1].Str  := 'na';
        a_1[1].Index := -1;
        a_1[1].Result := -1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'ssa';
        a_1[2].Index := -1;
        a_1[2].Result := -1;
        a_1[2].Method := nil;

        a_1[3].Str  := 'ta';
        a_1[3].Index := -1;
        a_1[3].Result := -1;
        a_1[3].Method := nil;

        a_1[4].Str  := 'lta';
        a_1[4].Index := 3;
        a_1[4].Result := -1;
        a_1[4].Method := nil;

        a_1[5].Str  := 'sta';
        a_1[5].Index := 3;
        a_1[5].Result := -1;
        a_1[5].Method := nil;

    SetLength(a_2, 6);
        a_2[0].Str  := 'll'#228;
        a_2[0].Index := -1;
        a_2[0].Result := -1;
        a_2[0].Method := nil;

        a_2[1].Str  := 'n'#228;
        a_2[1].Index := -1;
        a_2[1].Result := -1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'ss'#228;
        a_2[2].Index := -1;
        a_2[2].Result := -1;
        a_2[2].Method := nil;

        a_2[3].Str  := 't'#228;
        a_2[3].Index := -1;
        a_2[3].Result := -1;
        a_2[3].Method := nil;

        a_2[4].Str  := 'lt'#228;
        a_2[4].Index := 3;
        a_2[4].Result := -1;
        a_2[4].Method := nil;

        a_2[5].Str  := 'st'#228;
        a_2[5].Index := 3;
        a_2[5].Result := -1;
        a_2[5].Method := nil;

    SetLength(a_3, 2);
        a_3[0].Str  := 'lle';
        a_3[0].Index := -1;
        a_3[0].Result := -1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'ine';
        a_3[1].Index := -1;
        a_3[1].Result := -1;
        a_3[1].Method := nil;

    SetLength(a_4, 9);
        a_4[0].Str  := 'nsa';
        a_4[0].Index := -1;
        a_4[0].Result := 3;
        a_4[0].Method := nil;

        a_4[1].Str  := 'mme';
        a_4[1].Index := -1;
        a_4[1].Result := 3;
        a_4[1].Method := nil;

        a_4[2].Str  := 'nne';
        a_4[2].Index := -1;
        a_4[2].Result := 3;
        a_4[2].Method := nil;

        a_4[3].Str  := 'ni';
        a_4[3].Index := -1;
        a_4[3].Result := 2;
        a_4[3].Method := nil;

        a_4[4].Str  := 'si';
        a_4[4].Index := -1;
        a_4[4].Result := 1;
        a_4[4].Method := nil;

        a_4[5].Str  := 'an';
        a_4[5].Index := -1;
        a_4[5].Result := 4;
        a_4[5].Method := nil;

        a_4[6].Str  := 'en';
        a_4[6].Index := -1;
        a_4[6].Result := 6;
        a_4[6].Method := nil;

        a_4[7].Str  := #228'n';
        a_4[7].Index := -1;
        a_4[7].Result := 5;
        a_4[7].Method := nil;

        a_4[8].Str  := 'ns'#228;
        a_4[8].Index := -1;
        a_4[8].Result := 3;
        a_4[8].Method := nil;

    SetLength(a_5, 7);
        a_5[0].Str  := 'aa';
        a_5[0].Index := -1;
        a_5[0].Result := -1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'ee';
        a_5[1].Index := -1;
        a_5[1].Result := -1;
        a_5[1].Method := nil;

        a_5[2].Str  := 'ii';
        a_5[2].Index := -1;
        a_5[2].Result := -1;
        a_5[2].Method := nil;

        a_5[3].Str  := 'oo';
        a_5[3].Index := -1;
        a_5[3].Result := -1;
        a_5[3].Method := nil;

        a_5[4].Str  := 'uu';
        a_5[4].Index := -1;
        a_5[4].Result := -1;
        a_5[4].Method := nil;

        a_5[5].Str  := #228#228;
        a_5[5].Index := -1;
        a_5[5].Result := -1;
        a_5[5].Method := nil;

        a_5[6].Str  := #246#246;
        a_5[6].Index := -1;
        a_5[6].Result := -1;
        a_5[6].Method := nil;

    SetLength(a_6, 8);
        a_6[0].Str  := '''';
        a_6[0].Index := -1;
        a_6[0].Result := -1;
        a_6[0].Method := nil;

        a_6[1].Str  := 'ai';
        a_6[1].Index := -1;
        a_6[1].Result := -1;
        a_6[1].Method := nil;

        a_6[2].Str  := 'ei';
        a_6[2].Index := -1;
        a_6[2].Result := -1;
        a_6[2].Method := nil;

        a_6[3].Str  := 'ii';
        a_6[3].Index := -1;
        a_6[3].Result := -1;
        a_6[3].Method := nil;

        a_6[4].Str  := 'oi';
        a_6[4].Index := -1;
        a_6[4].Result := -1;
        a_6[4].Method := nil;

        a_6[5].Str  := 'ui';
        a_6[5].Index := -1;
        a_6[5].Result := -1;
        a_6[5].Method := nil;

        a_6[6].Str  := #228'i';
        a_6[6].Index := -1;
        a_6[6].Result := -1;
        a_6[6].Method := nil;

        a_6[7].Str  := #246'i';
        a_6[7].Index := -1;
        a_6[7].Result := -1;
        a_6[7].Method := nil;

    SetLength(a_7, 31);
        a_7[0].Str  := 'a';
        a_7[0].Index := -1;
        a_7[0].Result := 2;
        a_7[0].Method := nil;

        a_7[1].Str  := 'lla';
        a_7[1].Index := 0;
        a_7[1].Result := -1;
        a_7[1].Method := nil;

        a_7[2].Str  := 'na';
        a_7[2].Index := 0;
        a_7[2].Result := -1;
        a_7[2].Method := nil;

        a_7[3].Str  := 'ssa';
        a_7[3].Index := 0;
        a_7[3].Result := -1;
        a_7[3].Method := nil;

        a_7[4].Str  := 'ta';
        a_7[4].Index := 0;
        a_7[4].Result := -1;
        a_7[4].Method := nil;

        a_7[5].Str  := 'lta';
        a_7[5].Index := 4;
        a_7[5].Result := -1;
        a_7[5].Method := nil;

        a_7[6].Str  := 'sta';
        a_7[6].Index := 4;
        a_7[6].Result := -1;
        a_7[6].Method := nil;

        a_7[7].Str  := 'tta';
        a_7[7].Index := 4;
        a_7[7].Result := 3;
        a_7[7].Method := nil;

        a_7[8].Str  := 'lle';
        a_7[8].Index := -1;
        a_7[8].Result := -1;
        a_7[8].Method := nil;

        a_7[9].Str  := 'ine';
        a_7[9].Index := -1;
        a_7[9].Result := -1;
        a_7[9].Method := nil;

        a_7[10].Str  := 'ksi';
        a_7[10].Index := -1;
        a_7[10].Result := -1;
        a_7[10].Method := nil;

        a_7[11].Str  := 'n';
        a_7[11].Index := -1;
        a_7[11].Result := 1;
        a_7[11].Method := nil;

        a_7[12].Str  := 'han';
        a_7[12].Index := 11;
        a_7[12].Result := -1;
        a_7[12].Method := Self.r_A;

        a_7[13].Str  := 'den';
        a_7[13].Index := 11;
        a_7[13].Result := -1;
        a_7[13].Method := Self.r_VI;

        a_7[14].Str  := 'seen';
        a_7[14].Index := 11;
        a_7[14].Result := -1;
        a_7[14].Method := Self.r_LV;

        a_7[15].Str  := 'hen';
        a_7[15].Index := 11;
        a_7[15].Result := -1;
        a_7[15].Method := Self.r_E;

        a_7[16].Str  := 'tten';
        a_7[16].Index := 11;
        a_7[16].Result := -1;
        a_7[16].Method := Self.r_VI;

        a_7[17].Str  := 'hin';
        a_7[17].Index := 11;
        a_7[17].Result := -1;
        a_7[17].Method := Self.r_I;

        a_7[18].Str  := 'siin';
        a_7[18].Index := 11;
        a_7[18].Result := -1;
        a_7[18].Method := Self.r_VI;

        a_7[19].Str  := 'hon';
        a_7[19].Index := 11;
        a_7[19].Result := -1;
        a_7[19].Method := Self.r_O;

        a_7[20].Str  := 'hun';
        a_7[20].Index := 11;
        a_7[20].Result := -1;
        a_7[20].Method := Self.r_U;

        a_7[21].Str  := 'h'#228'n';
        a_7[21].Index := 11;
        a_7[21].Result := -1;
        a_7[21].Method := Self.r_A_;

        a_7[22].Str  := 'h'#246'n';
        a_7[22].Index := 11;
        a_7[22].Result := -1;
        a_7[22].Method := Self.r_O_;

        a_7[23].Str  := #228;
        a_7[23].Index := -1;
        a_7[23].Result := 2;
        a_7[23].Method := nil;

        a_7[24].Str  := 'll'#228;
        a_7[24].Index := 23;
        a_7[24].Result := -1;
        a_7[24].Method := nil;

        a_7[25].Str  := 'n'#228;
        a_7[25].Index := 23;
        a_7[25].Result := -1;
        a_7[25].Method := nil;

        a_7[26].Str  := 'ss'#228;
        a_7[26].Index := 23;
        a_7[26].Result := -1;
        a_7[26].Method := nil;

        a_7[27].Str  := 't'#228;
        a_7[27].Index := 23;
        a_7[27].Result := -1;
        a_7[27].Method := nil;

        a_7[28].Str  := 'lt'#228;
        a_7[28].Index := 27;
        a_7[28].Result := -1;
        a_7[28].Method := nil;

        a_7[29].Str  := 'st'#228;
        a_7[29].Index := 27;
        a_7[29].Result := -1;
        a_7[29].Method := nil;

        a_7[30].Str  := 'tt'#228;
        a_7[30].Index := 27;
        a_7[30].Result := 3;
        a_7[30].Method := nil;

    SetLength(a_8, 14);
        a_8[0].Str  := 'eja';
        a_8[0].Index := -1;
        a_8[0].Result := -1;
        a_8[0].Method := nil;

        a_8[1].Str  := 'mma';
        a_8[1].Index := -1;
        a_8[1].Result := 1;
        a_8[1].Method := nil;

        a_8[2].Str  := 'imma';
        a_8[2].Index := 1;
        a_8[2].Result := -1;
        a_8[2].Method := nil;

        a_8[3].Str  := 'mpa';
        a_8[3].Index := -1;
        a_8[3].Result := 1;
        a_8[3].Method := nil;

        a_8[4].Str  := 'impa';
        a_8[4].Index := 3;
        a_8[4].Result := -1;
        a_8[4].Method := nil;

        a_8[5].Str  := 'mmi';
        a_8[5].Index := -1;
        a_8[5].Result := 1;
        a_8[5].Method := nil;

        a_8[6].Str  := 'immi';
        a_8[6].Index := 5;
        a_8[6].Result := -1;
        a_8[6].Method := nil;

        a_8[7].Str  := 'mpi';
        a_8[7].Index := -1;
        a_8[7].Result := 1;
        a_8[7].Method := nil;

        a_8[8].Str  := 'impi';
        a_8[8].Index := 7;
        a_8[8].Result := -1;
        a_8[8].Method := nil;

        a_8[9].Str  := 'ej'#228;
        a_8[9].Index := -1;
        a_8[9].Result := -1;
        a_8[9].Method := nil;

        a_8[10].Str  := 'mm'#228;
        a_8[10].Index := -1;
        a_8[10].Result := 1;
        a_8[10].Method := nil;

        a_8[11].Str  := 'imm'#228;
        a_8[11].Index := 10;
        a_8[11].Result := -1;
        a_8[11].Method := nil;

        a_8[12].Str  := 'mp'#228;
        a_8[12].Index := -1;
        a_8[12].Result := 1;
        a_8[12].Method := nil;

        a_8[13].Str  := 'imp'#228;
        a_8[13].Index := 12;
        a_8[13].Result := -1;
        a_8[13].Method := nil;

    SetLength(a_9, 2);
        a_9[0].Str  := 'i';
        a_9[0].Index := -1;
        a_9[0].Result := -1;
        a_9[0].Method := nil;

        a_9[1].Str  := 'j';
        a_9[1].Index := -1;
        a_9[1].Result := -1;
        a_9[1].Method := nil;

    SetLength(a_10, 2);
        a_10[0].Str  := 'mma';
        a_10[0].Index := -1;
        a_10[0].Result := 1;
        a_10[0].Method := nil;

        a_10[1].Str  := 'imma';
        a_10[1].Index := 0;
        a_10[1].Result := -1;
        a_10[1].Method := nil;

End;

Function TFinnishStemmer.r_LV : Boolean;
Begin
    Result := FindAmongBk(a_5, 7) <> 0;
End;

Function TFinnishStemmer.r_VI : Boolean;
Begin
    Result := FindAmongBk(a_6, 8) <> 0;
End;

Function TFinnishStemmer.r_A : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk('a'))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_E : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk('e'))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_I : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk('i'))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_O : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk('o'))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_U : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk('u'))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_A_ : Boolean;
Label
    lab0;
Begin
    Repeat
        If (Not (EqSBk(#228))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.r_O_ : Boolean;
Label
    lab0,
    lab1;
Begin
    Repeat
        If (Not (EqSBk(#246))) Then
        Begin
            goto lab0;
        End;
        Break;
lab0:
        If (Not (EqSBk(#248))) Then
        Begin
            goto lab1;
        End;
        Break;
lab1:
        If (Not (EqSBk(''''))) Then
        Begin
            Begin Result := False; Exit; End;
        End;
    Until True;
    Result := True;
End;

Function TFinnishStemmer.stem : Boolean;
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
    AmongVar : Integer;
    B_ending_removed : Boolean;
    S_x : AnsiString;
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
    lab19;
Begin
    v_1 := FCursor;
    I_p1 := FLimit;
    I_p2 := FLimit;
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
    I_p2 := FCursor;
lab0:
    FCursor := v_1;
    B_ending_removed := False;
    FBkLimit := FCursor; FCursor := FLimit;
    v_2 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab1;
    End;
    v_3 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_0, 10);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_3;
        goto lab1;
    End;
    FBra := FCursor;
    FBkLimit := v_3;
    Case AmongVar Of
        1:
        Begin
            If (Not (InGroupingBk(g_particle_end, 97, 246))) Then
            Begin
                goto lab1;
            End;
        End;
        2:
        Begin
            If I_p2 > FCursor Then
            Begin
                goto lab1;
            End;
        End;
    End;
    SliceDel;
lab1:
    FCursor := FLimit - v_2;
    v_4 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab2;
    End;
    v_5 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_4, 9);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_5;
        goto lab2;
    End;
    FBra := FCursor;
    FBkLimit := v_5;
    Case AmongVar Of
        1:
        Begin
            If (Not (EqSBk('k'))) Then
            Begin
                goto lab3;
            End;
            goto lab2;
lab3:
            SliceDel;
        End;
        2:
        Begin
            SliceDel;
            FKet := FCursor;
            If (Not (EqSBk('kse'))) Then
            Begin
                goto lab2;
            End;
            FBra := FCursor;
            SliceFrom('ksi');
        End;
        3:
        Begin
            SliceDel;
        End;
        4:
        Begin
            If (FindAmongBk(a_1, 6) = 0) Then
            Begin
                goto lab2;
            End;
            SliceDel;
        End;
        5:
        Begin
            If (FindAmongBk(a_2, 6) = 0) Then
            Begin
                goto lab2;
            End;
            SliceDel;
        End;
        6:
        Begin
            If (FindAmongBk(a_3, 2) = 0) Then
            Begin
                goto lab2;
            End;
            SliceDel;
        End;
    End;
lab2:
    FCursor := FLimit - v_4;
    v_6 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab4;
    End;
    v_7 := FBkLimit;
    FBkLimit := I_p1;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_7, 31);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_7;
        goto lab4;
    End;
    FBra := FCursor;
    FBkLimit := v_7;
    Case AmongVar Of
        1:
        Begin
            v_8 := FLimit - FCursor;
            v_9 := FLimit - FCursor;
            Repeat
                v_10 := FLimit - FCursor;
                If (Not r_LV) Then
                Begin
                    goto lab6;
                End;
                Break;
lab6:
                FCursor := FLimit - v_10;
                If (Not (EqSBk('ie'))) Then
                Begin
                    FCursor := FLimit - v_8;
                    goto lab5;
                End;
            Until True;
            FCursor := FLimit - v_9;
            If (FCursor <= FBkLimit) Then
            Begin
                FCursor := FLimit - v_8;
                goto lab5;
            End;
            Dec(FCursor);
            FBra := FCursor;
lab5:
        End;
        2:
        Begin
            If (Not (InGroupingBk(g_v, 97, 246))) Then
            Begin
                goto lab4;
            End;
            If (Not (InGroupingBk(g_C, 98, 122))) Then
            Begin
                goto lab4;
            End;
        End;
        3:
        Begin
            If (Not (EqSBk('e'))) Then
            Begin
                goto lab4;
            End;
        End;
    End;
    SliceDel;
    B_ending_removed := True;
lab4:
    FCursor := FLimit - v_6;
    v_11 := FLimit - FCursor;
    If (FCursor < I_p2) Then
    Begin
        goto lab7;
    End;
    v_12 := FBkLimit;
    FBkLimit := I_p2;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_8, 14);
    If (AmongVar = 0) Then
    Begin
        FBkLimit := v_12;
        goto lab7;
    End;
    FBra := FCursor;
    FBkLimit := v_12;
    Case AmongVar Of
        1:
        Begin
            If (Not (EqSBk('po'))) Then
            Begin
                goto lab8;
            End;
            goto lab7;
lab8:
        End;
    End;
    SliceDel;
lab7:
    FCursor := FLimit - v_11;
    Repeat
        If (Not (B_ending_removed)) Then
        Begin
            goto lab9;
        End;
        v_13 := FLimit - FCursor;
        If (FCursor < I_p1) Then
        Begin
            goto lab10;
        End;
        v_14 := FBkLimit;
        FBkLimit := I_p1;
        FKet := FCursor;
        If (FindAmongBk(a_9, 2) = 0) Then
        Begin
            FBkLimit := v_14;
            goto lab10;
        End;
        FBra := FCursor;
        FBkLimit := v_14;
        SliceDel;
lab10:
        FCursor := FLimit - v_13;
        Break;
lab9:
        v_15 := FLimit - FCursor;
        If (FCursor < I_p1) Then
        Begin
            goto lab11;
        End;
        v_16 := FBkLimit;
        FBkLimit := I_p1;
        FKet := FCursor;
        If (Not (EqSBk('t'))) Then
        Begin
            FBkLimit := v_16;
            goto lab11;
        End;
        FBra := FCursor;
        v_17 := FLimit - FCursor;
        If (Not (InGroupingBk(g_v, 97, 246))) Then
        Begin
            FBkLimit := v_16;
            goto lab11;
        End;
        FCursor := FLimit - v_17;
        SliceDel;
        FBkLimit := v_16;
        If (FCursor < I_p2) Then
        Begin
            goto lab11;
        End;
        v_18 := FBkLimit;
        FBkLimit := I_p2;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_10, 2);
        If (AmongVar = 0) Then
        Begin
            FBkLimit := v_18;
            goto lab11;
        End;
        FBra := FCursor;
        FBkLimit := v_18;
        Case AmongVar Of
            1:
            Begin
                If (Not (EqSBk('po'))) Then
                Begin
                    goto lab12;
                End;
                goto lab11;
lab12:
            End;
        End;
        SliceDel;
lab11:
        FCursor := FLimit - v_15;
    Until True;
    v_19 := FLimit - FCursor;
    If (FCursor < I_p1) Then
    Begin
        goto lab13;
    End;
    v_20 := FBkLimit;
    FBkLimit := I_p1;
    v_21 := FLimit - FCursor;
    v_22 := FLimit - FCursor;
    If (Not r_LV) Then
    Begin
        goto lab14;
    End;
    FCursor := FLimit - v_22;
    FKet := FCursor;
    If (FCursor <= FBkLimit) Then
    Begin
        goto lab14;
    End;
    Dec(FCursor);
    FBra := FCursor;
    SliceDel;
lab14:
    FCursor := FLimit - v_21;
    v_23 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (InGroupingBk(g_AEI, 97, 228))) Then
    Begin
        goto lab15;
    End;
    FBra := FCursor;
    If (Not (InGroupingBk(g_C, 98, 122))) Then
    Begin
        goto lab15;
    End;
    SliceDel;
lab15:
    FCursor := FLimit - v_23;
    v_24 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (EqSBk('j'))) Then
    Begin
        goto lab16;
    End;
    FBra := FCursor;
    Repeat
        If (Not (EqSBk('o'))) Then
        Begin
            goto lab17;
        End;
        Break;
lab17:
        If (Not (EqSBk('u'))) Then
        Begin
            goto lab16;
        End;
    Until True;
    SliceDel;
lab16:
    FCursor := FLimit - v_24;
    v_25 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (EqSBk('o'))) Then
    Begin
        goto lab18;
    End;
    FBra := FCursor;
    If (Not (EqSBk('j'))) Then
    Begin
        goto lab18;
    End;
    SliceDel;
lab18:
    FCursor := FLimit - v_25;
    FBkLimit := v_20;
    v_26 := FLimit - FCursor;
    If (Not (GoInGroupingBk(g_v, 97, 246))) Then
    Begin
        goto lab19;
    End;
    FKet := FCursor;
    If (Not (InGroupingBk(g_C, 98, 122))) Then
    Begin
        goto lab19;
    End;
    FBra := FCursor;
    S_x := SliceTo();
    If (Not (EqSBk(S_x))) Then
    Begin
        goto lab19;
    End;
    SliceDel;
lab19:
    FCursor := FLimit - v_26;
    FKet := FCursor;
    If (Not (EqSBk(''''))) Then
    Begin
        goto lab13;
    End;
    FBra := FCursor;
    SliceDel;
lab13:
    FCursor := FLimit - v_19;
    FCursor := FBkLimit;
    Result := True;
End;

End.
