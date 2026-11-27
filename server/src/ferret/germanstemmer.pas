// Generated from german.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit GermanStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TGermanStemmer = Class(TSnowballProgram)
    private
        a_0 : Array Of TAmong;
        a_1 : Array Of TAmong;
        a_2 : Array Of TAmong;
        a_3 : Array Of TAmong;
        a_4 : Array Of TAmong;
        a_5 : Array Of TAmong;
        a_6 : Array Of TAmong;
        a_7 : Array Of TAmong;
    public
        Constructor Create;
        Function stem : Boolean; Override;
End;

Implementation

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
        Chr(0),
        Chr(8),
        Chr(0),
        Chr(32),
        Chr(8)
    );

Const
    g_et_ending : Array [0..17] Of Char = (
        Chr(1),
        Chr(128),
        Chr(198),
        Chr(227),
        Chr(32),
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
        Chr(128)
    );

Const
    g_s_ending : Array [0..2] Of Char = (
        Chr(117),
        Chr(30),
        Chr(5)
    );

Const
    g_st_ending : Array [0..2] Of Char = (
        Chr(117),
        Chr(30),
        Chr(4)
    );

Constructor TGermanStemmer.Create;
Begin
    SetLength(a_0, 6);
        a_0[0].Str  := '';
        a_0[0].Index := -1;
        a_0[0].Result := 5;
        a_0[0].Method := nil;

        a_0[1].Str  := 'ae';
        a_0[1].Index := 0;
        a_0[1].Result := 2;
        a_0[1].Method := nil;

        a_0[2].Str  := 'oe';
        a_0[2].Index := 0;
        a_0[2].Result := 3;
        a_0[2].Method := nil;

        a_0[3].Str  := 'qu';
        a_0[3].Index := 0;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'ue';
        a_0[4].Index := 0;
        a_0[4].Result := 4;
        a_0[4].Method := nil;

        a_0[5].Str  := #223;
        a_0[5].Index := 0;
        a_0[5].Result := 1;
        a_0[5].Method := nil;

    SetLength(a_1, 6);
        a_1[0].Str  := '';
        a_1[0].Index := -1;
        a_1[0].Result := 5;
        a_1[0].Method := nil;

        a_1[1].Str  := 'U';
        a_1[1].Index := 0;
        a_1[1].Result := 2;
        a_1[1].Method := nil;

        a_1[2].Str  := 'Y';
        a_1[2].Index := 0;
        a_1[2].Result := 1;
        a_1[2].Method := nil;

        a_1[3].Str  := #228;
        a_1[3].Index := 0;
        a_1[3].Result := 3;
        a_1[3].Method := nil;

        a_1[4].Str  := #246;
        a_1[4].Index := 0;
        a_1[4].Result := 4;
        a_1[4].Method := nil;

        a_1[5].Str  := #252;
        a_1[5].Index := 0;
        a_1[5].Result := 2;
        a_1[5].Method := nil;

    SetLength(a_2, 11);
        a_2[0].Str  := 'e';
        a_2[0].Index := -1;
        a_2[0].Result := 3;
        a_2[0].Method := nil;

        a_2[1].Str  := 'em';
        a_2[1].Index := -1;
        a_2[1].Result := 1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'en';
        a_2[2].Index := -1;
        a_2[2].Result := 3;
        a_2[2].Method := nil;

        a_2[3].Str  := 'erinnen';
        a_2[3].Index := 2;
        a_2[3].Result := 2;
        a_2[3].Method := nil;

        a_2[4].Str  := 'erin';
        a_2[4].Index := -1;
        a_2[4].Result := 2;
        a_2[4].Method := nil;

        a_2[5].Str  := 'ln';
        a_2[5].Index := -1;
        a_2[5].Result := 5;
        a_2[5].Method := nil;

        a_2[6].Str  := 'ern';
        a_2[6].Index := -1;
        a_2[6].Result := 2;
        a_2[6].Method := nil;

        a_2[7].Str  := 'er';
        a_2[7].Index := -1;
        a_2[7].Result := 2;
        a_2[7].Method := nil;

        a_2[8].Str  := 's';
        a_2[8].Index := -1;
        a_2[8].Result := 4;
        a_2[8].Method := nil;

        a_2[9].Str  := 'es';
        a_2[9].Index := 8;
        a_2[9].Result := 3;
        a_2[9].Method := nil;

        a_2[10].Str  := 'lns';
        a_2[10].Index := 8;
        a_2[10].Result := 5;
        a_2[10].Method := nil;

    SetLength(a_3, 5);
        a_3[0].Str  := 'tick';
        a_3[0].Index := -1;
        a_3[0].Result := -1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'plan';
        a_3[1].Index := -1;
        a_3[1].Result := -1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'geordn';
        a_3[2].Index := -1;
        a_3[2].Result := -1;
        a_3[2].Method := nil;

        a_3[3].Str  := 'intern';
        a_3[3].Index := -1;
        a_3[3].Result := -1;
        a_3[3].Method := nil;

        a_3[4].Str  := 'tr';
        a_3[4].Index := -1;
        a_3[4].Result := -1;
        a_3[4].Method := nil;

    SetLength(a_4, 5);
        a_4[0].Str  := 'en';
        a_4[0].Index := -1;
        a_4[0].Result := 1;
        a_4[0].Method := nil;

        a_4[1].Str  := 'er';
        a_4[1].Index := -1;
        a_4[1].Result := 1;
        a_4[1].Method := nil;

        a_4[2].Str  := 'et';
        a_4[2].Index := -1;
        a_4[2].Result := 3;
        a_4[2].Method := nil;

        a_4[3].Str  := 'st';
        a_4[3].Index := -1;
        a_4[3].Result := 2;
        a_4[3].Method := nil;

        a_4[4].Str  := 'est';
        a_4[4].Index := 3;
        a_4[4].Result := 1;
        a_4[4].Method := nil;

    SetLength(a_5, 2);
        a_5[0].Str  := 'ig';
        a_5[0].Index := -1;
        a_5[0].Result := 1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'lich';
        a_5[1].Index := -1;
        a_5[1].Result := 1;
        a_5[1].Method := nil;

    SetLength(a_6, 8);
        a_6[0].Str  := 'end';
        a_6[0].Index := -1;
        a_6[0].Result := 1;
        a_6[0].Method := nil;

        a_6[1].Str  := 'ig';
        a_6[1].Index := -1;
        a_6[1].Result := 2;
        a_6[1].Method := nil;

        a_6[2].Str  := 'ung';
        a_6[2].Index := -1;
        a_6[2].Result := 1;
        a_6[2].Method := nil;

        a_6[3].Str  := 'lich';
        a_6[3].Index := -1;
        a_6[3].Result := 3;
        a_6[3].Method := nil;

        a_6[4].Str  := 'isch';
        a_6[4].Index := -1;
        a_6[4].Result := 2;
        a_6[4].Method := nil;

        a_6[5].Str  := 'ik';
        a_6[5].Index := -1;
        a_6[5].Result := 2;
        a_6[5].Method := nil;

        a_6[6].Str  := 'heit';
        a_6[6].Index := -1;
        a_6[6].Result := 3;
        a_6[6].Method := nil;

        a_6[7].Str  := 'keit';
        a_6[7].Index := -1;
        a_6[7].Result := 4;
        a_6[7].Method := nil;

    SetLength(a_7, 3);
        a_7[0].Str  := '''';
        a_7[0].Index := -1;
        a_7[0].Result := 1;
        a_7[0].Method := nil;

        a_7[1].Str  := '''sch';
        a_7[1].Index := -1;
        a_7[1].Result := 1;
        a_7[1].Method := nil;

        a_7[2].Str  := '''s';
        a_7[2].Index := -1;
        a_7[2].Result := 1;
        a_7[2].Method := nil;

End;

Function TGermanStemmer.stem : Boolean;
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
    AmongVar : Integer;
    C : Integer;
    I_x : Integer;
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
    lab25;
Begin
    v_1 := FCursor;
    v_2 := FCursor;
lab1:
    Begin
        v_3 := FCursor;
        While True Do
        Begin
            v_4 := FCursor;
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab3;
            End;
            FBra := FCursor;
            Repeat
                v_5 := FCursor;
                If (Not (EqS('u'))) Then
                Begin
                    goto lab4;
                End;
                FKet := FCursor;
                If (Not (InGrouping(g_v, 97, 252))) Then
                Begin
                    goto lab4;
                End;
                SliceFrom('U');
                Break;
lab4:
                FCursor := v_5;
                If (Not (EqS('y'))) Then
                Begin
                    goto lab3;
                End;
                FKet := FCursor;
                If (Not (InGrouping(g_v, 97, 252))) Then
                Begin
                    goto lab3;
                End;
                SliceFrom('Y');
            Until True;
            FCursor := v_4;
            Break;
lab3:
            FCursor := v_4;
            If (FCursor >= FLimit) Then
            Begin
                goto lab2;
            End;
            Inc(FCursor);
        End;
        goto lab1;
lab2:
        FCursor := v_3;
    End;
    FCursor := v_2;
lab5:
    Begin
        v_6 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_0, 6);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('ss');
            End;
            2:
            Begin
                SliceFrom(#228);
            End;
            3:
            Begin
                SliceFrom(#246);
            End;
            4:
            Begin
                SliceFrom(#252);
            End;
            5:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab6;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab5;
lab6:
        FCursor := v_6;
    End;
lab0:
    FCursor := v_1;
    v_7 := FCursor;
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_8 := FCursor;
    Begin
        C := FCursor + 3;
        If (C > FLimit) Then
        Begin
            goto lab7;
        End;
        FCursor := C;
    End;
    I_x := FCursor;
    FCursor := v_8;
    If (Not (GoOutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab7;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 252))) Then
    Begin
        goto lab7;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If I_p1 >= I_x Then
    Begin
        goto lab8;
    End;
    I_p1 := I_x;
lab8:
    If (Not (GoOutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab7;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 252))) Then
    Begin
        goto lab7;
    End;
    Inc(FCursor);
    I_p2 := FCursor;
lab7:
    FCursor := v_7;
    FBkLimit := FCursor; FCursor := FLimit;
    v_9 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_2, 11);
    If (AmongVar = 0) Then
    Begin
        goto lab10;
    End;
    FBra := FCursor;
    If I_p1 > FCursor Then
    Begin
        goto lab10;
    End;
    Case AmongVar Of
        1:
        Begin
            If (Not (EqSBk('syst'))) Then
            Begin
                goto lab11;
            End;
            goto lab10;
lab11:
            SliceDel;
        End;
        2:
        Begin
            SliceDel;
        End;
        3:
        Begin
            SliceDel;
            v_10 := FLimit - FCursor;
            FKet := FCursor;
            If (Not (EqSBk('s'))) Then
            Begin
                FCursor := FLimit - v_10;
                goto lab12;
            End;
            FBra := FCursor;
            If (Not (EqSBk('nis'))) Then
            Begin
                FCursor := FLimit - v_10;
                goto lab12;
            End;
            SliceDel;
lab12:
        End;
        4:
        Begin
            If (Not (InGroupingBk(g_s_ending, 98, 116))) Then
            Begin
                goto lab10;
            End;
            SliceDel;
        End;
        5:
        Begin
            SliceFrom('l');
        End;
    End;
lab10:
    FCursor := FLimit - v_9;
    v_11 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_4, 5);
    If (AmongVar = 0) Then
    Begin
        goto lab13;
    End;
    FBra := FCursor;
    If I_p1 > FCursor Then
    Begin
        goto lab13;
    End;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            If (Not (InGroupingBk(g_st_ending, 98, 116))) Then
            Begin
                goto lab13;
            End;
            Begin
                C := FCursor - 3;
                If (C < FBkLimit) Then
                Begin
                    goto lab13;
                End;
                FCursor := C;
            End;
            SliceDel;
        End;
        3:
        Begin
            v_12 := FLimit - FCursor;
            If (Not (InGroupingBk(g_et_ending, 85, 228))) Then
            Begin
                goto lab13;
            End;
            FCursor := FLimit - v_12;
            Begin
                v_13 := FLimit - FCursor;
                If (FindAmongBk(a_3, 5) = 0) Then
                Begin
                    goto lab14;
                End;
                goto lab13;
lab14:
                FCursor := FLimit - v_13;
            End;
            SliceDel;
        End;
    End;
lab13:
    FCursor := FLimit - v_11;
    v_14 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_6, 8);
    If (AmongVar = 0) Then
    Begin
        goto lab15;
    End;
    FBra := FCursor;
    If I_p2 > FCursor Then
    Begin
        goto lab15;
    End;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
            v_15 := FLimit - FCursor;
            FKet := FCursor;
            If (Not (EqSBk('ig'))) Then
            Begin
                FCursor := FLimit - v_15;
                goto lab16;
            End;
            FBra := FCursor;
            If (Not (EqSBk('e'))) Then
            Begin
                goto lab17;
            End;
            FCursor := FLimit - v_15;
            goto lab16;
lab17:
            If I_p2 > FCursor Then
            Begin
                FCursor := FLimit - v_15;
                goto lab16;
            End;
            SliceDel;
lab16:
        End;
        2:
        Begin
            If (Not (EqSBk('e'))) Then
            Begin
                goto lab18;
            End;
            goto lab15;
lab18:
            SliceDel;
        End;
        3:
        Begin
            SliceDel;
            v_16 := FLimit - FCursor;
            FKet := FCursor;
            Repeat
                If (Not (EqSBk('er'))) Then
                Begin
                    goto lab20;
                End;
                Break;
lab20:
                If (Not (EqSBk('en'))) Then
                Begin
                    FCursor := FLimit - v_16;
                    goto lab19;
                End;
            Until True;
            FBra := FCursor;
            If I_p1 > FCursor Then
            Begin
                FCursor := FLimit - v_16;
                goto lab19;
            End;
            SliceDel;
lab19:
        End;
        4:
        Begin
            SliceDel;
            v_17 := FLimit - FCursor;
            FKet := FCursor;
            If (FindAmongBk(a_5, 2) = 0) Then
            Begin
                FCursor := FLimit - v_17;
                goto lab21;
            End;
            FBra := FCursor;
            If I_p2 > FCursor Then
            Begin
                FCursor := FLimit - v_17;
                goto lab21;
            End;
            SliceDel;
lab21:
        End;
    End;
lab15:
    FCursor := FLimit - v_14;
    v_18 := FLimit - FCursor;
    FKet := FCursor;
    If (FindAmongBk(a_7, 3) = 0) Then
    Begin
        goto lab22;
    End;
    FBra := FCursor;
    If (FCursor <= FBkLimit) Then
    Begin
        goto lab22;
    End;
    Dec(FCursor);
    If FCursor <= FBkLimit Then
    Begin
        goto lab22;
    End;
    SliceDel;
lab22:
    FCursor := FLimit - v_18;
lab9:
    FCursor := FBkLimit;
    v_19 := FCursor;
lab24:
    Begin
        v_20 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_1, 6);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('y');
            End;
            2:
            Begin
                SliceFrom('u');
            End;
            3:
            Begin
                SliceFrom('a');
            End;
            4:
            Begin
                SliceFrom('o');
            End;
            5:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab25;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab24;
lab25:
        FCursor := v_20;
    End;
lab23:
    FCursor := v_19;
    Result := True;
End;

End.
