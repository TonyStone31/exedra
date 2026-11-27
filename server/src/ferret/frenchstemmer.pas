// Generated from french.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit FrenchStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TFrenchStemmer = Class(TSnowballProgram)
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
        Chr(128),
        Chr(130),
        Chr(103),
        Chr(8),
        Chr(5)
    );

Const
    g_oux_ending : Array [0..1] Of Char = (
        Chr(65),
        Chr(85)
    );

Const
    g_elision_char : Array [0..2] Of Char = (
        Chr(131),
        Chr(14),
        Chr(131)
    );

Const
    g_keep_with_s : Array [0..16] Of Char = (
        Chr(1),
        Chr(65),
        Chr(20),
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
        Chr(128)
    );

Constructor TFrenchStemmer.Create;
Begin
    SetLength(a_0, 4);
        a_0[0].Str  := 'col';
        a_0[0].Index := -1;
        a_0[0].Result := -1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'ni';
        a_0[1].Index := -1;
        a_0[1].Result := 1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'par';
        a_0[2].Index := -1;
        a_0[2].Result := -1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'tap';
        a_0[3].Index := -1;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

    SetLength(a_1, 7);
        a_1[0].Str  := '';
        a_1[0].Index := -1;
        a_1[0].Result := 7;
        a_1[0].Method := nil;

        a_1[1].Str  := 'H';
        a_1[1].Index := 0;
        a_1[1].Result := 6;
        a_1[1].Method := nil;

        a_1[2].Str  := 'He';
        a_1[2].Index := 1;
        a_1[2].Result := 4;
        a_1[2].Method := nil;

        a_1[3].Str  := 'Hi';
        a_1[3].Index := 1;
        a_1[3].Result := 5;
        a_1[3].Method := nil;

        a_1[4].Str  := 'I';
        a_1[4].Index := 0;
        a_1[4].Result := 1;
        a_1[4].Method := nil;

        a_1[5].Str  := 'U';
        a_1[5].Index := 0;
        a_1[5].Result := 2;
        a_1[5].Method := nil;

        a_1[6].Str  := 'Y';
        a_1[6].Index := 0;
        a_1[6].Result := 3;
        a_1[6].Method := nil;

    SetLength(a_2, 6);
        a_2[0].Str  := 'iqU';
        a_2[0].Index := -1;
        a_2[0].Result := 3;
        a_2[0].Method := nil;

        a_2[1].Str  := 'abl';
        a_2[1].Index := -1;
        a_2[1].Result := 3;
        a_2[1].Method := nil;

        a_2[2].Str  := 'I'#232'r';
        a_2[2].Index := -1;
        a_2[2].Result := 4;
        a_2[2].Method := nil;

        a_2[3].Str  := 'i'#232'r';
        a_2[3].Index := -1;
        a_2[3].Result := 4;
        a_2[3].Method := nil;

        a_2[4].Str  := 'eus';
        a_2[4].Index := -1;
        a_2[4].Result := 2;
        a_2[4].Method := nil;

        a_2[5].Str  := 'iv';
        a_2[5].Index := -1;
        a_2[5].Result := 1;
        a_2[5].Method := nil;

    SetLength(a_3, 3);
        a_3[0].Str  := 'ic';
        a_3[0].Index := -1;
        a_3[0].Result := 2;
        a_3[0].Method := nil;

        a_3[1].Str  := 'abil';
        a_3[1].Index := -1;
        a_3[1].Result := 1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'iv';
        a_3[2].Index := -1;
        a_3[2].Result := 3;
        a_3[2].Method := nil;

    SetLength(a_4, 44);
        a_4[0].Str  := 'iqUe';
        a_4[0].Index := -1;
        a_4[0].Result := 1;
        a_4[0].Method := nil;

        a_4[1].Str  := 'atrice';
        a_4[1].Index := -1;
        a_4[1].Result := 2;
        a_4[1].Method := nil;

        a_4[2].Str  := 'ance';
        a_4[2].Index := -1;
        a_4[2].Result := 1;
        a_4[2].Method := nil;

        a_4[3].Str  := 'ence';
        a_4[3].Index := -1;
        a_4[3].Result := 5;
        a_4[3].Method := nil;

        a_4[4].Str  := 'logie';
        a_4[4].Index := -1;
        a_4[4].Result := 3;
        a_4[4].Method := nil;

        a_4[5].Str  := 'able';
        a_4[5].Index := -1;
        a_4[5].Result := 1;
        a_4[5].Method := nil;

        a_4[6].Str  := 'isme';
        a_4[6].Index := -1;
        a_4[6].Result := 1;
        a_4[6].Method := nil;

        a_4[7].Str  := 'euse';
        a_4[7].Index := -1;
        a_4[7].Result := 12;
        a_4[7].Method := nil;

        a_4[8].Str  := 'iste';
        a_4[8].Index := -1;
        a_4[8].Result := 1;
        a_4[8].Method := nil;

        a_4[9].Str  := 'ive';
        a_4[9].Index := -1;
        a_4[9].Result := 8;
        a_4[9].Method := nil;

        a_4[10].Str  := 'if';
        a_4[10].Index := -1;
        a_4[10].Result := 8;
        a_4[10].Method := nil;

        a_4[11].Str  := 'usion';
        a_4[11].Index := -1;
        a_4[11].Result := 4;
        a_4[11].Method := nil;

        a_4[12].Str  := 'ation';
        a_4[12].Index := -1;
        a_4[12].Result := 2;
        a_4[12].Method := nil;

        a_4[13].Str  := 'ution';
        a_4[13].Index := -1;
        a_4[13].Result := 4;
        a_4[13].Method := nil;

        a_4[14].Str  := 'ateur';
        a_4[14].Index := -1;
        a_4[14].Result := 2;
        a_4[14].Method := nil;

        a_4[15].Str  := 'iqUes';
        a_4[15].Index := -1;
        a_4[15].Result := 1;
        a_4[15].Method := nil;

        a_4[16].Str  := 'atrices';
        a_4[16].Index := -1;
        a_4[16].Result := 2;
        a_4[16].Method := nil;

        a_4[17].Str  := 'ances';
        a_4[17].Index := -1;
        a_4[17].Result := 1;
        a_4[17].Method := nil;

        a_4[18].Str  := 'ences';
        a_4[18].Index := -1;
        a_4[18].Result := 5;
        a_4[18].Method := nil;

        a_4[19].Str  := 'logies';
        a_4[19].Index := -1;
        a_4[19].Result := 3;
        a_4[19].Method := nil;

        a_4[20].Str  := 'ables';
        a_4[20].Index := -1;
        a_4[20].Result := 1;
        a_4[20].Method := nil;

        a_4[21].Str  := 'ismes';
        a_4[21].Index := -1;
        a_4[21].Result := 1;
        a_4[21].Method := nil;

        a_4[22].Str  := 'euses';
        a_4[22].Index := -1;
        a_4[22].Result := 12;
        a_4[22].Method := nil;

        a_4[23].Str  := 'istes';
        a_4[23].Index := -1;
        a_4[23].Result := 1;
        a_4[23].Method := nil;

        a_4[24].Str  := 'ives';
        a_4[24].Index := -1;
        a_4[24].Result := 8;
        a_4[24].Method := nil;

        a_4[25].Str  := 'ifs';
        a_4[25].Index := -1;
        a_4[25].Result := 8;
        a_4[25].Method := nil;

        a_4[26].Str  := 'usions';
        a_4[26].Index := -1;
        a_4[26].Result := 4;
        a_4[26].Method := nil;

        a_4[27].Str  := 'ations';
        a_4[27].Index := -1;
        a_4[27].Result := 2;
        a_4[27].Method := nil;

        a_4[28].Str  := 'utions';
        a_4[28].Index := -1;
        a_4[28].Result := 4;
        a_4[28].Method := nil;

        a_4[29].Str  := 'ateurs';
        a_4[29].Index := -1;
        a_4[29].Result := 2;
        a_4[29].Method := nil;

        a_4[30].Str  := 'ments';
        a_4[30].Index := -1;
        a_4[30].Result := 16;
        a_4[30].Method := nil;

        a_4[31].Str  := 'ements';
        a_4[31].Index := 30;
        a_4[31].Result := 6;
        a_4[31].Method := nil;

        a_4[32].Str  := 'issements';
        a_4[32].Index := 31;
        a_4[32].Result := 13;
        a_4[32].Method := nil;

        a_4[33].Str  := 'it'#233's';
        a_4[33].Index := -1;
        a_4[33].Result := 7;
        a_4[33].Method := nil;

        a_4[34].Str  := 'ment';
        a_4[34].Index := -1;
        a_4[34].Result := 16;
        a_4[34].Method := nil;

        a_4[35].Str  := 'ement';
        a_4[35].Index := 34;
        a_4[35].Result := 6;
        a_4[35].Method := nil;

        a_4[36].Str  := 'issement';
        a_4[36].Index := 35;
        a_4[36].Result := 13;
        a_4[36].Method := nil;

        a_4[37].Str  := 'amment';
        a_4[37].Index := 34;
        a_4[37].Result := 14;
        a_4[37].Method := nil;

        a_4[38].Str  := 'emment';
        a_4[38].Index := 34;
        a_4[38].Result := 15;
        a_4[38].Method := nil;

        a_4[39].Str  := 'aux';
        a_4[39].Index := -1;
        a_4[39].Result := 10;
        a_4[39].Method := nil;

        a_4[40].Str  := 'eaux';
        a_4[40].Index := 39;
        a_4[40].Result := 9;
        a_4[40].Method := nil;

        a_4[41].Str  := 'eux';
        a_4[41].Index := -1;
        a_4[41].Result := 1;
        a_4[41].Method := nil;

        a_4[42].Str  := 'oux';
        a_4[42].Index := -1;
        a_4[42].Result := 11;
        a_4[42].Method := nil;

        a_4[43].Str  := 'it'#233;
        a_4[43].Index := -1;
        a_4[43].Result := 7;
        a_4[43].Method := nil;

    SetLength(a_5, 35);
        a_5[0].Str  := 'ira';
        a_5[0].Index := -1;
        a_5[0].Result := 1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'ie';
        a_5[1].Index := -1;
        a_5[1].Result := 1;
        a_5[1].Method := nil;

        a_5[2].Str  := 'isse';
        a_5[2].Index := -1;
        a_5[2].Result := 1;
        a_5[2].Method := nil;

        a_5[3].Str  := 'issante';
        a_5[3].Index := -1;
        a_5[3].Result := 1;
        a_5[3].Method := nil;

        a_5[4].Str  := 'i';
        a_5[4].Index := -1;
        a_5[4].Result := 1;
        a_5[4].Method := nil;

        a_5[5].Str  := 'irai';
        a_5[5].Index := 4;
        a_5[5].Result := 1;
        a_5[5].Method := nil;

        a_5[6].Str  := 'ir';
        a_5[6].Index := -1;
        a_5[6].Result := 1;
        a_5[6].Method := nil;

        a_5[7].Str  := 'iras';
        a_5[7].Index := -1;
        a_5[7].Result := 1;
        a_5[7].Method := nil;

        a_5[8].Str  := 'ies';
        a_5[8].Index := -1;
        a_5[8].Result := 1;
        a_5[8].Method := nil;

        a_5[9].Str  := #238'mes';
        a_5[9].Index := -1;
        a_5[9].Result := 1;
        a_5[9].Method := nil;

        a_5[10].Str  := 'isses';
        a_5[10].Index := -1;
        a_5[10].Result := 1;
        a_5[10].Method := nil;

        a_5[11].Str  := 'issantes';
        a_5[11].Index := -1;
        a_5[11].Result := 1;
        a_5[11].Method := nil;

        a_5[12].Str  := #238'tes';
        a_5[12].Index := -1;
        a_5[12].Result := 1;
        a_5[12].Method := nil;

        a_5[13].Str  := 'is';
        a_5[13].Index := -1;
        a_5[13].Result := 1;
        a_5[13].Method := nil;

        a_5[14].Str  := 'irais';
        a_5[14].Index := 13;
        a_5[14].Result := 1;
        a_5[14].Method := nil;

        a_5[15].Str  := 'issais';
        a_5[15].Index := 13;
        a_5[15].Result := 1;
        a_5[15].Method := nil;

        a_5[16].Str  := 'irions';
        a_5[16].Index := -1;
        a_5[16].Result := 1;
        a_5[16].Method := nil;

        a_5[17].Str  := 'issions';
        a_5[17].Index := -1;
        a_5[17].Result := 1;
        a_5[17].Method := nil;

        a_5[18].Str  := 'irons';
        a_5[18].Index := -1;
        a_5[18].Result := 1;
        a_5[18].Method := nil;

        a_5[19].Str  := 'issons';
        a_5[19].Index := -1;
        a_5[19].Result := 1;
        a_5[19].Method := nil;

        a_5[20].Str  := 'issants';
        a_5[20].Index := -1;
        a_5[20].Result := 1;
        a_5[20].Method := nil;

        a_5[21].Str  := 'it';
        a_5[21].Index := -1;
        a_5[21].Result := 1;
        a_5[21].Method := nil;

        a_5[22].Str  := 'irait';
        a_5[22].Index := 21;
        a_5[22].Result := 1;
        a_5[22].Method := nil;

        a_5[23].Str  := 'issait';
        a_5[23].Index := 21;
        a_5[23].Result := 1;
        a_5[23].Method := nil;

        a_5[24].Str  := 'issant';
        a_5[24].Index := -1;
        a_5[24].Result := 1;
        a_5[24].Method := nil;

        a_5[25].Str  := 'iraIent';
        a_5[25].Index := -1;
        a_5[25].Result := 1;
        a_5[25].Method := nil;

        a_5[26].Str  := 'issaIent';
        a_5[26].Index := -1;
        a_5[26].Result := 1;
        a_5[26].Method := nil;

        a_5[27].Str  := 'irent';
        a_5[27].Index := -1;
        a_5[27].Result := 1;
        a_5[27].Method := nil;

        a_5[28].Str  := 'issent';
        a_5[28].Index := -1;
        a_5[28].Result := 1;
        a_5[28].Method := nil;

        a_5[29].Str  := 'iront';
        a_5[29].Index := -1;
        a_5[29].Result := 1;
        a_5[29].Method := nil;

        a_5[30].Str  := #238't';
        a_5[30].Index := -1;
        a_5[30].Result := 1;
        a_5[30].Method := nil;

        a_5[31].Str  := 'iriez';
        a_5[31].Index := -1;
        a_5[31].Result := 1;
        a_5[31].Method := nil;

        a_5[32].Str  := 'issiez';
        a_5[32].Index := -1;
        a_5[32].Result := 1;
        a_5[32].Method := nil;

        a_5[33].Str  := 'irez';
        a_5[33].Index := -1;
        a_5[33].Result := 1;
        a_5[33].Method := nil;

        a_5[34].Str  := 'issez';
        a_5[34].Index := -1;
        a_5[34].Result := 1;
        a_5[34].Method := nil;

    SetLength(a_6, 3);
        a_6[0].Str  := 'al';
        a_6[0].Index := -1;
        a_6[0].Result := 1;
        a_6[0].Method := nil;

        a_6[1].Str  := #233'pl';
        a_6[1].Index := -1;
        a_6[1].Result := -1;
        a_6[1].Method := nil;

        a_6[2].Str  := 'auv';
        a_6[2].Index := -1;
        a_6[2].Result := -1;
        a_6[2].Method := nil;

    SetLength(a_7, 41);
        a_7[0].Str  := 'a';
        a_7[0].Index := -1;
        a_7[0].Result := 3;
        a_7[0].Method := nil;

        a_7[1].Str  := 'era';
        a_7[1].Index := 0;
        a_7[1].Result := 2;
        a_7[1].Method := nil;

        a_7[2].Str  := 'aise';
        a_7[2].Index := -1;
        a_7[2].Result := 4;
        a_7[2].Method := nil;

        a_7[3].Str  := 'asse';
        a_7[3].Index := -1;
        a_7[3].Result := 3;
        a_7[3].Method := nil;

        a_7[4].Str  := 'ante';
        a_7[4].Index := -1;
        a_7[4].Result := 3;
        a_7[4].Method := nil;

        a_7[5].Str  := #233'e';
        a_7[5].Index := -1;
        a_7[5].Result := 2;
        a_7[5].Method := nil;

        a_7[6].Str  := 'ai';
        a_7[6].Index := -1;
        a_7[6].Result := 3;
        a_7[6].Method := nil;

        a_7[7].Str  := 'erai';
        a_7[7].Index := 6;
        a_7[7].Result := 2;
        a_7[7].Method := nil;

        a_7[8].Str  := 'er';
        a_7[8].Index := -1;
        a_7[8].Result := 2;
        a_7[8].Method := nil;

        a_7[9].Str  := 'as';
        a_7[9].Index := -1;
        a_7[9].Result := 3;
        a_7[9].Method := nil;

        a_7[10].Str  := 'eras';
        a_7[10].Index := 9;
        a_7[10].Result := 2;
        a_7[10].Method := nil;

        a_7[11].Str  := #226'mes';
        a_7[11].Index := -1;
        a_7[11].Result := 3;
        a_7[11].Method := nil;

        a_7[12].Str  := 'aises';
        a_7[12].Index := -1;
        a_7[12].Result := 4;
        a_7[12].Method := nil;

        a_7[13].Str  := 'asses';
        a_7[13].Index := -1;
        a_7[13].Result := 3;
        a_7[13].Method := nil;

        a_7[14].Str  := 'antes';
        a_7[14].Index := -1;
        a_7[14].Result := 3;
        a_7[14].Method := nil;

        a_7[15].Str  := #226'tes';
        a_7[15].Index := -1;
        a_7[15].Result := 3;
        a_7[15].Method := nil;

        a_7[16].Str  := #233'es';
        a_7[16].Index := -1;
        a_7[16].Result := 2;
        a_7[16].Method := nil;

        a_7[17].Str  := 'ais';
        a_7[17].Index := -1;
        a_7[17].Result := 4;
        a_7[17].Method := nil;

        a_7[18].Str  := 'eais';
        a_7[18].Index := 17;
        a_7[18].Result := 2;
        a_7[18].Method := nil;

        a_7[19].Str  := 'erais';
        a_7[19].Index := 17;
        a_7[19].Result := 2;
        a_7[19].Method := nil;

        a_7[20].Str  := 'ions';
        a_7[20].Index := -1;
        a_7[20].Result := 1;
        a_7[20].Method := nil;

        a_7[21].Str  := 'erions';
        a_7[21].Index := 20;
        a_7[21].Result := 2;
        a_7[21].Method := nil;

        a_7[22].Str  := 'assions';
        a_7[22].Index := 20;
        a_7[22].Result := 3;
        a_7[22].Method := nil;

        a_7[23].Str  := 'erons';
        a_7[23].Index := -1;
        a_7[23].Result := 2;
        a_7[23].Method := nil;

        a_7[24].Str  := 'ants';
        a_7[24].Index := -1;
        a_7[24].Result := 3;
        a_7[24].Method := nil;

        a_7[25].Str  := #233's';
        a_7[25].Index := -1;
        a_7[25].Result := 2;
        a_7[25].Method := nil;

        a_7[26].Str  := 'ait';
        a_7[26].Index := -1;
        a_7[26].Result := 3;
        a_7[26].Method := nil;

        a_7[27].Str  := 'erait';
        a_7[27].Index := 26;
        a_7[27].Result := 2;
        a_7[27].Method := nil;

        a_7[28].Str  := 'ant';
        a_7[28].Index := -1;
        a_7[28].Result := 3;
        a_7[28].Method := nil;

        a_7[29].Str  := 'aIent';
        a_7[29].Index := -1;
        a_7[29].Result := 3;
        a_7[29].Method := nil;

        a_7[30].Str  := 'eraIent';
        a_7[30].Index := 29;
        a_7[30].Result := 2;
        a_7[30].Method := nil;

        a_7[31].Str  := #232'rent';
        a_7[31].Index := -1;
        a_7[31].Result := 2;
        a_7[31].Method := nil;

        a_7[32].Str  := 'assent';
        a_7[32].Index := -1;
        a_7[32].Result := 3;
        a_7[32].Method := nil;

        a_7[33].Str  := 'eront';
        a_7[33].Index := -1;
        a_7[33].Result := 2;
        a_7[33].Method := nil;

        a_7[34].Str  := #226't';
        a_7[34].Index := -1;
        a_7[34].Result := 3;
        a_7[34].Method := nil;

        a_7[35].Str  := 'ez';
        a_7[35].Index := -1;
        a_7[35].Result := 2;
        a_7[35].Method := nil;

        a_7[36].Str  := 'iez';
        a_7[36].Index := 35;
        a_7[36].Result := 2;
        a_7[36].Method := nil;

        a_7[37].Str  := 'eriez';
        a_7[37].Index := 36;
        a_7[37].Result := 2;
        a_7[37].Method := nil;

        a_7[38].Str  := 'assiez';
        a_7[38].Index := 36;
        a_7[38].Result := 3;
        a_7[38].Method := nil;

        a_7[39].Str  := 'erez';
        a_7[39].Index := 35;
        a_7[39].Result := 2;
        a_7[39].Method := nil;

        a_7[40].Str  := #233;
        a_7[40].Index := -1;
        a_7[40].Result := 2;
        a_7[40].Method := nil;

    SetLength(a_8, 6);
        a_8[0].Str  := 'e';
        a_8[0].Index := -1;
        a_8[0].Result := 3;
        a_8[0].Method := nil;

        a_8[1].Str  := 'I'#232're';
        a_8[1].Index := 0;
        a_8[1].Result := 2;
        a_8[1].Method := nil;

        a_8[2].Str  := 'i'#232're';
        a_8[2].Index := 0;
        a_8[2].Result := 2;
        a_8[2].Method := nil;

        a_8[3].Str  := 'ion';
        a_8[3].Index := -1;
        a_8[3].Result := 1;
        a_8[3].Method := nil;

        a_8[4].Str  := 'Ier';
        a_8[4].Index := -1;
        a_8[4].Result := 2;
        a_8[4].Method := nil;

        a_8[5].Str  := 'ier';
        a_8[5].Index := -1;
        a_8[5].Result := 2;
        a_8[5].Method := nil;

    SetLength(a_9, 5);
        a_9[0].Str  := 'ell';
        a_9[0].Index := -1;
        a_9[0].Result := -1;
        a_9[0].Method := nil;

        a_9[1].Str  := 'eill';
        a_9[1].Index := -1;
        a_9[1].Result := -1;
        a_9[1].Method := nil;

        a_9[2].Str  := 'enn';
        a_9[2].Index := -1;
        a_9[2].Result := -1;
        a_9[2].Method := nil;

        a_9[3].Str  := 'onn';
        a_9[3].Index := -1;
        a_9[3].Result := -1;
        a_9[3].Method := nil;

        a_9[4].Str  := 'ett';
        a_9[4].Index := -1;
        a_9[4].Result := -1;
        a_9[4].Method := nil;

End;

Function TFrenchStemmer.stem : Boolean;
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
    v_34 : Integer;
    v_35 : Integer;
    v_36 : Integer;
    v_37 : Integer;
    v_38 : Integer;
    v_39 : Integer;
    AmongVar : Integer;
    I_p2 : Integer;
    I_p1 : Integer;
    I_pV : Integer;
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
    lab42,
    lab43,
    lab44,
    lab45,
    lab46;
Begin
    v_1 := FCursor;
    FBra := FCursor;
    Repeat
        If (Not (InGrouping(g_elision_char, 99, 122))) Then
        Begin
            goto lab1;
        End;
        Break;
lab1:
        If (Not (EqS('qu'))) Then
        Begin
            goto lab0;
        End;
    Until True;
    If (Not (EqS(''''))) Then
    Begin
        goto lab0;
    End;
    FKet := FCursor;
    If FCursor >= FLimit Then
    Begin
        goto lab0;
    End;
    SliceDel;
lab0:
    FCursor := v_1;
    v_2 := FCursor;
lab3:
    Begin
        v_3 := FCursor;
        While True Do
        Begin
            v_4 := FCursor;
            Repeat
                v_5 := FCursor;
                If (Not (InGrouping(g_v, 97, 251))) Then
                Begin
                    goto lab6;
                End;
                FBra := FCursor;
                Repeat
                    v_6 := FCursor;
                    If (Not (EqS('u'))) Then
                    Begin
                        goto lab7;
                    End;
                    FKet := FCursor;
                    If (Not (InGrouping(g_v, 97, 251))) Then
                    Begin
                        goto lab7;
                    End;
                    SliceFrom('U');
                    Break;
lab7:
                    FCursor := v_6;
                    If (Not (EqS('i'))) Then
                    Begin
                        goto lab8;
                    End;
                    FKet := FCursor;
                    If (Not (InGrouping(g_v, 97, 251))) Then
                    Begin
                        goto lab8;
                    End;
                    SliceFrom('I');
                    Break;
lab8:
                    FCursor := v_6;
                    If (Not (EqS('y'))) Then
                    Begin
                        goto lab6;
                    End;
                    FKet := FCursor;
                    SliceFrom('Y');
                Until True;
                Break;
lab6:
                FCursor := v_5;
                FBra := FCursor;
                If (Not (EqS(#235))) Then
                Begin
                    goto lab9;
                End;
                FKet := FCursor;
                SliceFrom('He');
                Break;
lab9:
                FCursor := v_5;
                FBra := FCursor;
                If (Not (EqS(#239))) Then
                Begin
                    goto lab10;
                End;
                FKet := FCursor;
                SliceFrom('Hi');
                Break;
lab10:
                FCursor := v_5;
                FBra := FCursor;
                If (Not (EqS('y'))) Then
                Begin
                    goto lab11;
                End;
                FKet := FCursor;
                If (Not (InGrouping(g_v, 97, 251))) Then
                Begin
                    goto lab11;
                End;
                SliceFrom('Y');
                Break;
lab11:
                FCursor := v_5;
                If (Not (EqS('q'))) Then
                Begin
                    goto lab5;
                End;
                FBra := FCursor;
                If (Not (EqS('u'))) Then
                Begin
                    goto lab5;
                End;
                FKet := FCursor;
                SliceFrom('U');
            Until True;
            FCursor := v_4;
            Break;
lab5:
            FCursor := v_4;
            If (FCursor >= FLimit) Then
            Begin
                goto lab4;
            End;
            Inc(FCursor);
        End;
        goto lab3;
lab4:
        FCursor := v_3;
    End;
lab2:
    FCursor := v_2;
    I_pV := FLimit;
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_7 := FCursor;
    Repeat
        v_8 := FCursor;
        If (Not (InGrouping(g_v, 97, 251))) Then
        Begin
            goto lab14;
        End;
        If (Not (InGrouping(g_v, 97, 251))) Then
        Begin
            goto lab14;
        End;
        If (FCursor >= FLimit) Then
        Begin
            goto lab14;
        End;
        Inc(FCursor);
        Break;
lab14:
        FCursor := v_8;
        AmongVar := FindAmong(a_0, 4);
        If (AmongVar = 0) Then
        Begin
            goto lab15;
        End;
        Case AmongVar Of
            1:
            Begin
                If (Not (InGrouping(g_v, 97, 251))) Then
                Begin
                    goto lab15;
                End;
            End;
        End;
        Break;
lab15:
        FCursor := v_8;
        If (FCursor >= FLimit) Then
        Begin
            goto lab13;
        End;
        Inc(FCursor);
        If (Not (GoOutGrouping(g_v, 97, 251))) Then
        Begin
            goto lab13;
        End;
        Inc(FCursor);
    Until True;
    I_pV := FCursor;
lab13:
    FCursor := v_7;
    v_9 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 251))) Then
    Begin
        goto lab16;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 251))) Then
    Begin
        goto lab16;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 251))) Then
    Begin
        goto lab16;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 251))) Then
    Begin
        goto lab16;
    End;
    Inc(FCursor);
    I_p2 := FCursor;
lab16:
    FCursor := v_9;
lab12:
    FBkLimit := FCursor; FCursor := FLimit;
    v_10 := FLimit - FCursor;
    Repeat
        v_11 := FLimit - FCursor;
        v_12 := FLimit - FCursor;
        Repeat
            v_13 := FLimit - FCursor;
            FKet := FCursor;
            AmongVar := FindAmongBk(a_4, 44);
            If (AmongVar = 0) Then
            Begin
                goto lab19;
            End;
            FBra := FCursor;
            Case AmongVar Of
                1:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                End;
                2:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                    v_14 := FLimit - FCursor;
                    FKet := FCursor;
                    If (Not (EqSBk('ic'))) Then
                    Begin
                        FCursor := FLimit - v_14;
                        goto lab20;
                    End;
                    FBra := FCursor;
                    Repeat
                        v_15 := FLimit - FCursor;
                        If I_p2 > FCursor Then
                        Begin
                            goto lab21;
                        End;
                        SliceDel;
                        Break;
lab21:
                        FCursor := FLimit - v_15;
                        SliceFrom('iqU');
                    Until True;
lab20:
                End;
                3:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('log');
                End;
                4:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('u');
                End;
                5:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('ent');
                End;
                6:
                Begin
                    If I_pV > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                    v_16 := FLimit - FCursor;
                    FKet := FCursor;
                    AmongVar := FindAmongBk(a_2, 6);
                    If (AmongVar = 0) Then
                    Begin
                        FCursor := FLimit - v_16;
                        goto lab22;
                    End;
                    FBra := FCursor;
                    Case AmongVar Of
                        1:
                        Begin
                            If I_p2 > FCursor Then
                            Begin
                                FCursor := FLimit - v_16;
                                goto lab22;
                            End;
                            SliceDel;
                            FKet := FCursor;
                            If (Not (EqSBk('at'))) Then
                            Begin
                                FCursor := FLimit - v_16;
                                goto lab22;
                            End;
                            FBra := FCursor;
                            If I_p2 > FCursor Then
                            Begin
                                FCursor := FLimit - v_16;
                                goto lab22;
                            End;
                            SliceDel;
                        End;
                        2:
                        Begin
                            Repeat
                                v_17 := FLimit - FCursor;
                                If I_p2 > FCursor Then
                                Begin
                                    goto lab23;
                                End;
                                SliceDel;
                                Break;
lab23:
                                FCursor := FLimit - v_17;
                                If I_p1 > FCursor Then
                                Begin
                                    FCursor := FLimit - v_16;
                                    goto lab22;
                                End;
                                SliceFrom('eux');
                            Until True;
                        End;
                        3:
                        Begin
                            If I_p2 > FCursor Then
                            Begin
                                FCursor := FLimit - v_16;
                                goto lab22;
                            End;
                            SliceDel;
                        End;
                        4:
                        Begin
                            If I_pV > FCursor Then
                            Begin
                                FCursor := FLimit - v_16;
                                goto lab22;
                            End;
                            SliceFrom('i');
                        End;
                    End;
lab22:
                End;
                7:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                    v_18 := FLimit - FCursor;
                    FKet := FCursor;
                    AmongVar := FindAmongBk(a_3, 3);
                    If (AmongVar = 0) Then
                    Begin
                        FCursor := FLimit - v_18;
                        goto lab24;
                    End;
                    FBra := FCursor;
                    Case AmongVar Of
                        1:
                        Begin
                            Repeat
                                v_19 := FLimit - FCursor;
                                If I_p2 > FCursor Then
                                Begin
                                    goto lab25;
                                End;
                                SliceDel;
                                Break;
lab25:
                                FCursor := FLimit - v_19;
                                SliceFrom('abl');
                            Until True;
                        End;
                        2:
                        Begin
                            Repeat
                                v_20 := FLimit - FCursor;
                                If I_p2 > FCursor Then
                                Begin
                                    goto lab26;
                                End;
                                SliceDel;
                                Break;
lab26:
                                FCursor := FLimit - v_20;
                                SliceFrom('iqU');
                            Until True;
                        End;
                        3:
                        Begin
                            If I_p2 > FCursor Then
                            Begin
                                FCursor := FLimit - v_18;
                                goto lab24;
                            End;
                            SliceDel;
                        End;
                    End;
lab24:
                End;
                8:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                    v_21 := FLimit - FCursor;
                    FKet := FCursor;
                    If (Not (EqSBk('at'))) Then
                    Begin
                        FCursor := FLimit - v_21;
                        goto lab27;
                    End;
                    FBra := FCursor;
                    If I_p2 > FCursor Then
                    Begin
                        FCursor := FLimit - v_21;
                        goto lab27;
                    End;
                    SliceDel;
                    FKet := FCursor;
                    If (Not (EqSBk('ic'))) Then
                    Begin
                        FCursor := FLimit - v_21;
                        goto lab27;
                    End;
                    FBra := FCursor;
                    Repeat
                        v_22 := FLimit - FCursor;
                        If I_p2 > FCursor Then
                        Begin
                            goto lab28;
                        End;
                        SliceDel;
                        Break;
lab28:
                        FCursor := FLimit - v_22;
                        SliceFrom('iqU');
                    Until True;
lab27:
                End;
                9:
                Begin
                    SliceFrom('eau');
                End;
                10:
                Begin
                    If I_p1 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('al');
                End;
                11:
                Begin
                    If (Not (InGroupingBk(g_oux_ending, 98, 112))) Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('ou');
                End;
                12:
                Begin
                    Repeat
                        v_23 := FLimit - FCursor;
                        If I_p2 > FCursor Then
                        Begin
                            goto lab29;
                        End;
                        SliceDel;
                        Break;
lab29:
                        FCursor := FLimit - v_23;
                        If I_p1 > FCursor Then
                        Begin
                            goto lab19;
                        End;
                        SliceFrom('eux');
                    Until True;
                End;
                13:
                Begin
                    If I_p1 > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    If (Not (OutGroupingBk(g_v, 97, 251))) Then
                    Begin
                        goto lab19;
                    End;
                    SliceDel;
                End;
                14:
                Begin
                    If I_pV > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('ant');
                    goto lab19;
                End;
                15:
                Begin
                    If I_pV > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    SliceFrom('ent');
                    goto lab19;
                End;
                16:
                Begin
                    v_24 := FLimit - FCursor;
                    If (Not (InGroupingBk(g_v, 97, 251))) Then
                    Begin
                        goto lab19;
                    End;
                    If I_pV > FCursor Then
                    Begin
                        goto lab19;
                    End;
                    FCursor := FLimit - v_24;
                    SliceDel;
                    goto lab19;
                End;
            End;
            Break;
lab19:
            FCursor := FLimit - v_13;
            If (FCursor < I_pV) Then
            Begin
                goto lab30;
            End;
            v_25 := FBkLimit;
            FBkLimit := I_pV;
            FKet := FCursor;
            If (FindAmongBk(a_5, 35) = 0) Then
            Begin
                FBkLimit := v_25;
                goto lab30;
            End;
            FBra := FCursor;
            If (Not (EqSBk('H'))) Then
            Begin
                goto lab31;
            End;
            FBkLimit := v_25;
            goto lab30;
lab31:
            If (Not (OutGroupingBk(g_v, 97, 251))) Then
            Begin
                FBkLimit := v_25;
                goto lab30;
            End;
            SliceDel;
            FBkLimit := v_25;
            Break;
lab30:
            FCursor := FLimit - v_13;
            If (FCursor < I_pV) Then
            Begin
                goto lab18;
            End;
            v_26 := FBkLimit;
            FBkLimit := I_pV;
            FKet := FCursor;
            AmongVar := FindAmongBk(a_7, 41);
            If (AmongVar = 0) Then
            Begin
                FBkLimit := v_26;
                goto lab18;
            End;
            FBra := FCursor;
            FBkLimit := v_26;
            Case AmongVar Of
                1:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab18;
                    End;
                    SliceDel;
                End;
                2:
                Begin
                    SliceDel;
                End;
                3:
                Begin
                    v_27 := FLimit - FCursor;
                    If (Not (EqSBk('e'))) Then
                    Begin
                        FCursor := FLimit - v_27;
                        goto lab32;
                    End;
                    If I_pV > FCursor Then
                    Begin
                        FCursor := FLimit - v_27;
                        goto lab32;
                    End;
                    FBra := FCursor;
lab32:
                    SliceDel;
                End;
                4:
                Begin
                    Begin
                        v_28 := FLimit - FCursor;
                        AmongVar := FindAmongBk(a_6, 3);
                        If (AmongVar = 0) Then
                        Begin
                            goto lab33;
                        End;
                        Case AmongVar Of
                            1:
                            Begin
                                If (FCursor <= FBkLimit) Then
                                Begin
                                    goto lab33;
                                End;
                                Dec(FCursor);
                                If FCursor > FBkLimit Then
                                Begin
                                    goto lab33;
                                End;
                            End;
                        End;
                        goto lab18;
lab33:
                        FCursor := FLimit - v_28;
                    End;
                    SliceDel;
                End;
            End;
        Until True;
        FCursor := FLimit - v_12;
        v_29 := FLimit - FCursor;
        FKet := FCursor;
        Repeat
            v_30 := FLimit - FCursor;
            If (Not (EqSBk('Y'))) Then
            Begin
                goto lab35;
            End;
            FBra := FCursor;
            SliceFrom('i');
            Break;
lab35:
            FCursor := FLimit - v_30;
            If (Not (EqSBk(#231))) Then
            Begin
                FCursor := FLimit - v_29;
                goto lab34;
            End;
            FBra := FCursor;
            SliceFrom('c');
        Until True;
lab34:
        Break;
lab18:
        FCursor := FLimit - v_11;
        v_31 := FLimit - FCursor;
        FKet := FCursor;
        If (Not (EqSBk('s'))) Then
        Begin
            FCursor := FLimit - v_31;
            goto lab36;
        End;
        FBra := FCursor;
        v_32 := FLimit - FCursor;
        Repeat
            If (Not (EqSBk('Hi'))) Then
            Begin
                goto lab37;
            End;
            Break;
lab37:
            If (Not (OutGroupingBk(g_keep_with_s, 97, 232))) Then
            Begin
                FCursor := FLimit - v_31;
                goto lab36;
            End;
        Until True;
        FCursor := FLimit - v_32;
        SliceDel;
lab36:
        If (FCursor < I_pV) Then
        Begin
            goto lab17;
        End;
        v_33 := FBkLimit;
        FBkLimit := I_pV;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_8, 6);
        If (AmongVar = 0) Then
        Begin
            FBkLimit := v_33;
            goto lab17;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                If I_p2 > FCursor Then
                Begin
                    FBkLimit := v_33;
                    goto lab17;
                End;
                Repeat
                    If (Not (EqSBk('s'))) Then
                    Begin
                        goto lab38;
                    End;
                    Break;
lab38:
                    If (Not (EqSBk('t'))) Then
                    Begin
                        FBkLimit := v_33;
                        goto lab17;
                    End;
                Until True;
                SliceDel;
            End;
            2:
            Begin
                SliceFrom('i');
            End;
            3:
            Begin
                SliceDel;
            End;
        End;
        FBkLimit := v_33;
    Until True;
lab17:
    FCursor := FLimit - v_10;
    v_34 := FLimit - FCursor;
    v_35 := FLimit - FCursor;
    If (FindAmongBk(a_9, 5) = 0) Then
    Begin
        goto lab39;
    End;
    FCursor := FLimit - v_35;
    FKet := FCursor;
    If (FCursor <= FBkLimit) Then
    Begin
        goto lab39;
    End;
    Dec(FCursor);
    FBra := FCursor;
    SliceDel;
lab39:
    FCursor := FLimit - v_34;
    v_36 := FLimit - FCursor;
    Begin
        v_37 := 1;
lab41:
        Begin
            If (Not (OutGroupingBk(g_v, 97, 251))) Then
            Begin
                goto lab42;
            End;
            Dec(v_37);
            goto lab41;
lab42:
        End;
        If (v_37 > 0) Then
        Begin
            goto lab40;
        End;
    End;
    FKet := FCursor;
    Repeat
        If (Not (EqSBk(#233))) Then
        Begin
            goto lab43;
        End;
        Break;
lab43:
        If (Not (EqSBk(#232))) Then
        Begin
            goto lab40;
        End;
    Until True;
    FBra := FCursor;
    SliceFrom('e');
lab40:
    FCursor := FLimit - v_36;
    FCursor := FBkLimit;
    v_38 := FCursor;
lab45:
    Begin
        v_39 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_1, 7);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('i');
            End;
            2:
            Begin
                SliceFrom('u');
            End;
            3:
            Begin
                SliceFrom('y');
            End;
            4:
            Begin
                SliceFrom(#235);
            End;
            5:
            Begin
                SliceFrom(#239);
            End;
            6:
            Begin
                SliceDel;
            End;
            7:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab46;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab45;
lab46:
        FCursor := v_39;
    End;
lab44:
    FCursor := v_38;
    Result := True;
End;

End.
