// Generated from italian.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit ItalianStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TItalianStemmer = Class(TSnowballProgram)
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
        Chr(128),
        Chr(8),
        Chr(2),
        Chr(1)
    );

Const
    g_AEIO : Array [0..18] Of Char = (
        Chr(17),
        Chr(65),
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
        Chr(128),
        Chr(128),
        Chr(8),
        Chr(2)
    );

Const
    g_CG : Array [0..0] Of Char = (
        Chr(17)
    );

Constructor TItalianStemmer.Create;
Begin
    SetLength(a_0, 16);
        a_0[0].Str  := 'all''';
        a_0[0].Index := -1;
        a_0[0].Result := -1;
        a_0[0].Method := nil;

        a_0[1].Str  := 'd''';
        a_0[1].Index := -1;
        a_0[1].Result := -1;
        a_0[1].Method := nil;

        a_0[2].Str  := 'dall''';
        a_0[2].Index := -1;
        a_0[2].Result := -1;
        a_0[2].Method := nil;

        a_0[3].Str  := 'dell''';
        a_0[3].Index := -1;
        a_0[3].Result := -1;
        a_0[3].Method := nil;

        a_0[4].Str  := 'gl''';
        a_0[4].Index := -1;
        a_0[4].Result := -1;
        a_0[4].Method := nil;

        a_0[5].Str  := 'l''';
        a_0[5].Index := -1;
        a_0[5].Result := -1;
        a_0[5].Method := nil;

        a_0[6].Str  := 'm''';
        a_0[6].Index := -1;
        a_0[6].Result := -1;
        a_0[6].Method := nil;

        a_0[7].Str  := 'nell''';
        a_0[7].Index := -1;
        a_0[7].Result := -1;
        a_0[7].Method := nil;

        a_0[8].Str  := 'quell''';
        a_0[8].Index := -1;
        a_0[8].Result := -1;
        a_0[8].Method := nil;

        a_0[9].Str  := 'quest''';
        a_0[9].Index := -1;
        a_0[9].Result := -1;
        a_0[9].Method := nil;

        a_0[10].Str  := 's''';
        a_0[10].Index := -1;
        a_0[10].Result := -1;
        a_0[10].Method := nil;

        a_0[11].Str  := 'sull''';
        a_0[11].Index := -1;
        a_0[11].Result := -1;
        a_0[11].Method := nil;

        a_0[12].Str  := 't''';
        a_0[12].Index := -1;
        a_0[12].Result := -1;
        a_0[12].Method := nil;

        a_0[13].Str  := 'tutt''';
        a_0[13].Index := -1;
        a_0[13].Result := -1;
        a_0[13].Method := nil;

        a_0[14].Str  := 'un''';
        a_0[14].Index := -1;
        a_0[14].Result := -1;
        a_0[14].Method := nil;

        a_0[15].Str  := 'v''';
        a_0[15].Index := -1;
        a_0[15].Result := -1;
        a_0[15].Method := nil;

    SetLength(a_1, 7);
        a_1[0].Str  := '';
        a_1[0].Index := -1;
        a_1[0].Result := 7;
        a_1[0].Method := nil;

        a_1[1].Str  := 'qu';
        a_1[1].Index := 0;
        a_1[1].Result := 6;
        a_1[1].Method := nil;

        a_1[2].Str  := #225;
        a_1[2].Index := 0;
        a_1[2].Result := 1;
        a_1[2].Method := nil;

        a_1[3].Str  := #233;
        a_1[3].Index := 0;
        a_1[3].Result := 2;
        a_1[3].Method := nil;

        a_1[4].Str  := #237;
        a_1[4].Index := 0;
        a_1[4].Result := 3;
        a_1[4].Method := nil;

        a_1[5].Str  := #243;
        a_1[5].Index := 0;
        a_1[5].Result := 4;
        a_1[5].Method := nil;

        a_1[6].Str  := #250;
        a_1[6].Index := 0;
        a_1[6].Result := 5;
        a_1[6].Method := nil;

    SetLength(a_2, 3);
        a_2[0].Str  := '';
        a_2[0].Index := -1;
        a_2[0].Result := 3;
        a_2[0].Method := nil;

        a_2[1].Str  := 'I';
        a_2[1].Index := 0;
        a_2[1].Result := 1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'U';
        a_2[2].Index := 0;
        a_2[2].Result := 2;
        a_2[2].Method := nil;

    SetLength(a_3, 37);
        a_3[0].Str  := 'la';
        a_3[0].Index := -1;
        a_3[0].Result := -1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'cela';
        a_3[1].Index := 0;
        a_3[1].Result := -1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'gliela';
        a_3[2].Index := 0;
        a_3[2].Result := -1;
        a_3[2].Method := nil;

        a_3[3].Str  := 'mela';
        a_3[3].Index := 0;
        a_3[3].Result := -1;
        a_3[3].Method := nil;

        a_3[4].Str  := 'tela';
        a_3[4].Index := 0;
        a_3[4].Result := -1;
        a_3[4].Method := nil;

        a_3[5].Str  := 'vela';
        a_3[5].Index := 0;
        a_3[5].Result := -1;
        a_3[5].Method := nil;

        a_3[6].Str  := 'le';
        a_3[6].Index := -1;
        a_3[6].Result := -1;
        a_3[6].Method := nil;

        a_3[7].Str  := 'cele';
        a_3[7].Index := 6;
        a_3[7].Result := -1;
        a_3[7].Method := nil;

        a_3[8].Str  := 'gliele';
        a_3[8].Index := 6;
        a_3[8].Result := -1;
        a_3[8].Method := nil;

        a_3[9].Str  := 'mele';
        a_3[9].Index := 6;
        a_3[9].Result := -1;
        a_3[9].Method := nil;

        a_3[10].Str  := 'tele';
        a_3[10].Index := 6;
        a_3[10].Result := -1;
        a_3[10].Method := nil;

        a_3[11].Str  := 'vele';
        a_3[11].Index := 6;
        a_3[11].Result := -1;
        a_3[11].Method := nil;

        a_3[12].Str  := 'ne';
        a_3[12].Index := -1;
        a_3[12].Result := -1;
        a_3[12].Method := nil;

        a_3[13].Str  := 'cene';
        a_3[13].Index := 12;
        a_3[13].Result := -1;
        a_3[13].Method := nil;

        a_3[14].Str  := 'gliene';
        a_3[14].Index := 12;
        a_3[14].Result := -1;
        a_3[14].Method := nil;

        a_3[15].Str  := 'mene';
        a_3[15].Index := 12;
        a_3[15].Result := -1;
        a_3[15].Method := nil;

        a_3[16].Str  := 'sene';
        a_3[16].Index := 12;
        a_3[16].Result := -1;
        a_3[16].Method := nil;

        a_3[17].Str  := 'tene';
        a_3[17].Index := 12;
        a_3[17].Result := -1;
        a_3[17].Method := nil;

        a_3[18].Str  := 'vene';
        a_3[18].Index := 12;
        a_3[18].Result := -1;
        a_3[18].Method := nil;

        a_3[19].Str  := 'ci';
        a_3[19].Index := -1;
        a_3[19].Result := -1;
        a_3[19].Method := nil;

        a_3[20].Str  := 'li';
        a_3[20].Index := -1;
        a_3[20].Result := -1;
        a_3[20].Method := nil;

        a_3[21].Str  := 'celi';
        a_3[21].Index := 20;
        a_3[21].Result := -1;
        a_3[21].Method := nil;

        a_3[22].Str  := 'glieli';
        a_3[22].Index := 20;
        a_3[22].Result := -1;
        a_3[22].Method := nil;

        a_3[23].Str  := 'meli';
        a_3[23].Index := 20;
        a_3[23].Result := -1;
        a_3[23].Method := nil;

        a_3[24].Str  := 'teli';
        a_3[24].Index := 20;
        a_3[24].Result := -1;
        a_3[24].Method := nil;

        a_3[25].Str  := 'veli';
        a_3[25].Index := 20;
        a_3[25].Result := -1;
        a_3[25].Method := nil;

        a_3[26].Str  := 'gli';
        a_3[26].Index := 20;
        a_3[26].Result := -1;
        a_3[26].Method := nil;

        a_3[27].Str  := 'mi';
        a_3[27].Index := -1;
        a_3[27].Result := -1;
        a_3[27].Method := nil;

        a_3[28].Str  := 'si';
        a_3[28].Index := -1;
        a_3[28].Result := -1;
        a_3[28].Method := nil;

        a_3[29].Str  := 'ti';
        a_3[29].Index := -1;
        a_3[29].Result := -1;
        a_3[29].Method := nil;

        a_3[30].Str  := 'vi';
        a_3[30].Index := -1;
        a_3[30].Result := -1;
        a_3[30].Method := nil;

        a_3[31].Str  := 'lo';
        a_3[31].Index := -1;
        a_3[31].Result := -1;
        a_3[31].Method := nil;

        a_3[32].Str  := 'celo';
        a_3[32].Index := 31;
        a_3[32].Result := -1;
        a_3[32].Method := nil;

        a_3[33].Str  := 'glielo';
        a_3[33].Index := 31;
        a_3[33].Result := -1;
        a_3[33].Method := nil;

        a_3[34].Str  := 'melo';
        a_3[34].Index := 31;
        a_3[34].Result := -1;
        a_3[34].Method := nil;

        a_3[35].Str  := 'telo';
        a_3[35].Index := 31;
        a_3[35].Result := -1;
        a_3[35].Method := nil;

        a_3[36].Str  := 'velo';
        a_3[36].Index := 31;
        a_3[36].Result := -1;
        a_3[36].Method := nil;

    SetLength(a_4, 5);
        a_4[0].Str  := 'ando';
        a_4[0].Index := -1;
        a_4[0].Result := 1;
        a_4[0].Method := nil;

        a_4[1].Str  := 'endo';
        a_4[1].Index := -1;
        a_4[1].Result := 1;
        a_4[1].Method := nil;

        a_4[2].Str  := 'ar';
        a_4[2].Index := -1;
        a_4[2].Result := 2;
        a_4[2].Method := nil;

        a_4[3].Str  := 'er';
        a_4[3].Index := -1;
        a_4[3].Result := 2;
        a_4[3].Method := nil;

        a_4[4].Str  := 'ir';
        a_4[4].Index := -1;
        a_4[4].Result := 2;
        a_4[4].Method := nil;

    SetLength(a_5, 4);
        a_5[0].Str  := 'ic';
        a_5[0].Index := -1;
        a_5[0].Result := -1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'abil';
        a_5[1].Index := -1;
        a_5[1].Result := -1;
        a_5[1].Method := nil;

        a_5[2].Str  := 'os';
        a_5[2].Index := -1;
        a_5[2].Result := -1;
        a_5[2].Method := nil;

        a_5[3].Str  := 'iv';
        a_5[3].Index := -1;
        a_5[3].Result := 1;
        a_5[3].Method := nil;

    SetLength(a_6, 3);
        a_6[0].Str  := 'ic';
        a_6[0].Index := -1;
        a_6[0].Result := 1;
        a_6[0].Method := nil;

        a_6[1].Str  := 'abil';
        a_6[1].Index := -1;
        a_6[1].Result := 1;
        a_6[1].Method := nil;

        a_6[2].Str  := 'iv';
        a_6[2].Index := -1;
        a_6[2].Result := 1;
        a_6[2].Method := nil;

    SetLength(a_7, 51);
        a_7[0].Str  := 'ica';
        a_7[0].Index := -1;
        a_7[0].Result := 1;
        a_7[0].Method := nil;

        a_7[1].Str  := 'logia';
        a_7[1].Index := -1;
        a_7[1].Result := 3;
        a_7[1].Method := nil;

        a_7[2].Str  := 'osa';
        a_7[2].Index := -1;
        a_7[2].Result := 1;
        a_7[2].Method := nil;

        a_7[3].Str  := 'ista';
        a_7[3].Index := -1;
        a_7[3].Result := 1;
        a_7[3].Method := nil;

        a_7[4].Str  := 'iva';
        a_7[4].Index := -1;
        a_7[4].Result := 9;
        a_7[4].Method := nil;

        a_7[5].Str  := 'anza';
        a_7[5].Index := -1;
        a_7[5].Result := 1;
        a_7[5].Method := nil;

        a_7[6].Str  := 'enza';
        a_7[6].Index := -1;
        a_7[6].Result := 5;
        a_7[6].Method := nil;

        a_7[7].Str  := 'ice';
        a_7[7].Index := -1;
        a_7[7].Result := 1;
        a_7[7].Method := nil;

        a_7[8].Str  := 'atrice';
        a_7[8].Index := 7;
        a_7[8].Result := 1;
        a_7[8].Method := nil;

        a_7[9].Str  := 'iche';
        a_7[9].Index := -1;
        a_7[9].Result := 1;
        a_7[9].Method := nil;

        a_7[10].Str  := 'logie';
        a_7[10].Index := -1;
        a_7[10].Result := 3;
        a_7[10].Method := nil;

        a_7[11].Str  := 'abile';
        a_7[11].Index := -1;
        a_7[11].Result := 1;
        a_7[11].Method := nil;

        a_7[12].Str  := 'ibile';
        a_7[12].Index := -1;
        a_7[12].Result := 1;
        a_7[12].Method := nil;

        a_7[13].Str  := 'usione';
        a_7[13].Index := -1;
        a_7[13].Result := 4;
        a_7[13].Method := nil;

        a_7[14].Str  := 'azione';
        a_7[14].Index := -1;
        a_7[14].Result := 2;
        a_7[14].Method := nil;

        a_7[15].Str  := 'uzione';
        a_7[15].Index := -1;
        a_7[15].Result := 4;
        a_7[15].Method := nil;

        a_7[16].Str  := 'atore';
        a_7[16].Index := -1;
        a_7[16].Result := 2;
        a_7[16].Method := nil;

        a_7[17].Str  := 'ose';
        a_7[17].Index := -1;
        a_7[17].Result := 1;
        a_7[17].Method := nil;

        a_7[18].Str  := 'ante';
        a_7[18].Index := -1;
        a_7[18].Result := 1;
        a_7[18].Method := nil;

        a_7[19].Str  := 'mente';
        a_7[19].Index := -1;
        a_7[19].Result := 1;
        a_7[19].Method := nil;

        a_7[20].Str  := 'amente';
        a_7[20].Index := 19;
        a_7[20].Result := 7;
        a_7[20].Method := nil;

        a_7[21].Str  := 'iste';
        a_7[21].Index := -1;
        a_7[21].Result := 1;
        a_7[21].Method := nil;

        a_7[22].Str  := 'ive';
        a_7[22].Index := -1;
        a_7[22].Result := 9;
        a_7[22].Method := nil;

        a_7[23].Str  := 'anze';
        a_7[23].Index := -1;
        a_7[23].Result := 1;
        a_7[23].Method := nil;

        a_7[24].Str  := 'enze';
        a_7[24].Index := -1;
        a_7[24].Result := 5;
        a_7[24].Method := nil;

        a_7[25].Str  := 'ici';
        a_7[25].Index := -1;
        a_7[25].Result := 1;
        a_7[25].Method := nil;

        a_7[26].Str  := 'atrici';
        a_7[26].Index := 25;
        a_7[26].Result := 1;
        a_7[26].Method := nil;

        a_7[27].Str  := 'ichi';
        a_7[27].Index := -1;
        a_7[27].Result := 1;
        a_7[27].Method := nil;

        a_7[28].Str  := 'abili';
        a_7[28].Index := -1;
        a_7[28].Result := 1;
        a_7[28].Method := nil;

        a_7[29].Str  := 'ibili';
        a_7[29].Index := -1;
        a_7[29].Result := 1;
        a_7[29].Method := nil;

        a_7[30].Str  := 'ismi';
        a_7[30].Index := -1;
        a_7[30].Result := 1;
        a_7[30].Method := nil;

        a_7[31].Str  := 'usioni';
        a_7[31].Index := -1;
        a_7[31].Result := 4;
        a_7[31].Method := nil;

        a_7[32].Str  := 'azioni';
        a_7[32].Index := -1;
        a_7[32].Result := 2;
        a_7[32].Method := nil;

        a_7[33].Str  := 'uzioni';
        a_7[33].Index := -1;
        a_7[33].Result := 4;
        a_7[33].Method := nil;

        a_7[34].Str  := 'atori';
        a_7[34].Index := -1;
        a_7[34].Result := 2;
        a_7[34].Method := nil;

        a_7[35].Str  := 'osi';
        a_7[35].Index := -1;
        a_7[35].Result := 1;
        a_7[35].Method := nil;

        a_7[36].Str  := 'anti';
        a_7[36].Index := -1;
        a_7[36].Result := 1;
        a_7[36].Method := nil;

        a_7[37].Str  := 'amenti';
        a_7[37].Index := -1;
        a_7[37].Result := 6;
        a_7[37].Method := nil;

        a_7[38].Str  := 'imenti';
        a_7[38].Index := -1;
        a_7[38].Result := 6;
        a_7[38].Method := nil;

        a_7[39].Str  := 'isti';
        a_7[39].Index := -1;
        a_7[39].Result := 1;
        a_7[39].Method := nil;

        a_7[40].Str  := 'ivi';
        a_7[40].Index := -1;
        a_7[40].Result := 9;
        a_7[40].Method := nil;

        a_7[41].Str  := 'ico';
        a_7[41].Index := -1;
        a_7[41].Result := 1;
        a_7[41].Method := nil;

        a_7[42].Str  := 'ismo';
        a_7[42].Index := -1;
        a_7[42].Result := 1;
        a_7[42].Method := nil;

        a_7[43].Str  := 'oso';
        a_7[43].Index := -1;
        a_7[43].Result := 1;
        a_7[43].Method := nil;

        a_7[44].Str  := 'amento';
        a_7[44].Index := -1;
        a_7[44].Result := 6;
        a_7[44].Method := nil;

        a_7[45].Str  := 'imento';
        a_7[45].Index := -1;
        a_7[45].Result := 6;
        a_7[45].Method := nil;

        a_7[46].Str  := 'ivo';
        a_7[46].Index := -1;
        a_7[46].Result := 9;
        a_7[46].Method := nil;

        a_7[47].Str  := 'it'#224;
        a_7[47].Index := -1;
        a_7[47].Result := 8;
        a_7[47].Method := nil;

        a_7[48].Str  := 'ist'#224;
        a_7[48].Index := -1;
        a_7[48].Result := 1;
        a_7[48].Method := nil;

        a_7[49].Str  := 'ist'#232;
        a_7[49].Index := -1;
        a_7[49].Result := 1;
        a_7[49].Method := nil;

        a_7[50].Str  := 'ist'#236;
        a_7[50].Index := -1;
        a_7[50].Result := 1;
        a_7[50].Method := nil;

    SetLength(a_8, 87);
        a_8[0].Str  := 'isca';
        a_8[0].Index := -1;
        a_8[0].Result := 1;
        a_8[0].Method := nil;

        a_8[1].Str  := 'enda';
        a_8[1].Index := -1;
        a_8[1].Result := 1;
        a_8[1].Method := nil;

        a_8[2].Str  := 'ata';
        a_8[2].Index := -1;
        a_8[2].Result := 1;
        a_8[2].Method := nil;

        a_8[3].Str  := 'ita';
        a_8[3].Index := -1;
        a_8[3].Result := 1;
        a_8[3].Method := nil;

        a_8[4].Str  := 'uta';
        a_8[4].Index := -1;
        a_8[4].Result := 1;
        a_8[4].Method := nil;

        a_8[5].Str  := 'ava';
        a_8[5].Index := -1;
        a_8[5].Result := 1;
        a_8[5].Method := nil;

        a_8[6].Str  := 'eva';
        a_8[6].Index := -1;
        a_8[6].Result := 1;
        a_8[6].Method := nil;

        a_8[7].Str  := 'iva';
        a_8[7].Index := -1;
        a_8[7].Result := 1;
        a_8[7].Method := nil;

        a_8[8].Str  := 'erebbe';
        a_8[8].Index := -1;
        a_8[8].Result := 1;
        a_8[8].Method := nil;

        a_8[9].Str  := 'irebbe';
        a_8[9].Index := -1;
        a_8[9].Result := 1;
        a_8[9].Method := nil;

        a_8[10].Str  := 'isce';
        a_8[10].Index := -1;
        a_8[10].Result := 1;
        a_8[10].Method := nil;

        a_8[11].Str  := 'ende';
        a_8[11].Index := -1;
        a_8[11].Result := 1;
        a_8[11].Method := nil;

        a_8[12].Str  := 'are';
        a_8[12].Index := -1;
        a_8[12].Result := 1;
        a_8[12].Method := nil;

        a_8[13].Str  := 'ere';
        a_8[13].Index := -1;
        a_8[13].Result := 1;
        a_8[13].Method := nil;

        a_8[14].Str  := 'ire';
        a_8[14].Index := -1;
        a_8[14].Result := 1;
        a_8[14].Method := nil;

        a_8[15].Str  := 'asse';
        a_8[15].Index := -1;
        a_8[15].Result := 1;
        a_8[15].Method := nil;

        a_8[16].Str  := 'ate';
        a_8[16].Index := -1;
        a_8[16].Result := 1;
        a_8[16].Method := nil;

        a_8[17].Str  := 'avate';
        a_8[17].Index := 16;
        a_8[17].Result := 1;
        a_8[17].Method := nil;

        a_8[18].Str  := 'evate';
        a_8[18].Index := 16;
        a_8[18].Result := 1;
        a_8[18].Method := nil;

        a_8[19].Str  := 'ivate';
        a_8[19].Index := 16;
        a_8[19].Result := 1;
        a_8[19].Method := nil;

        a_8[20].Str  := 'ete';
        a_8[20].Index := -1;
        a_8[20].Result := 1;
        a_8[20].Method := nil;

        a_8[21].Str  := 'erete';
        a_8[21].Index := 20;
        a_8[21].Result := 1;
        a_8[21].Method := nil;

        a_8[22].Str  := 'irete';
        a_8[22].Index := 20;
        a_8[22].Result := 1;
        a_8[22].Method := nil;

        a_8[23].Str  := 'ite';
        a_8[23].Index := -1;
        a_8[23].Result := 1;
        a_8[23].Method := nil;

        a_8[24].Str  := 'ereste';
        a_8[24].Index := -1;
        a_8[24].Result := 1;
        a_8[24].Method := nil;

        a_8[25].Str  := 'ireste';
        a_8[25].Index := -1;
        a_8[25].Result := 1;
        a_8[25].Method := nil;

        a_8[26].Str  := 'ute';
        a_8[26].Index := -1;
        a_8[26].Result := 1;
        a_8[26].Method := nil;

        a_8[27].Str  := 'erai';
        a_8[27].Index := -1;
        a_8[27].Result := 1;
        a_8[27].Method := nil;

        a_8[28].Str  := 'irai';
        a_8[28].Index := -1;
        a_8[28].Result := 1;
        a_8[28].Method := nil;

        a_8[29].Str  := 'isci';
        a_8[29].Index := -1;
        a_8[29].Result := 1;
        a_8[29].Method := nil;

        a_8[30].Str  := 'endi';
        a_8[30].Index := -1;
        a_8[30].Result := 1;
        a_8[30].Method := nil;

        a_8[31].Str  := 'erei';
        a_8[31].Index := -1;
        a_8[31].Result := 1;
        a_8[31].Method := nil;

        a_8[32].Str  := 'irei';
        a_8[32].Index := -1;
        a_8[32].Result := 1;
        a_8[32].Method := nil;

        a_8[33].Str  := 'assi';
        a_8[33].Index := -1;
        a_8[33].Result := 1;
        a_8[33].Method := nil;

        a_8[34].Str  := 'ati';
        a_8[34].Index := -1;
        a_8[34].Result := 1;
        a_8[34].Method := nil;

        a_8[35].Str  := 'iti';
        a_8[35].Index := -1;
        a_8[35].Result := 1;
        a_8[35].Method := nil;

        a_8[36].Str  := 'eresti';
        a_8[36].Index := -1;
        a_8[36].Result := 1;
        a_8[36].Method := nil;

        a_8[37].Str  := 'iresti';
        a_8[37].Index := -1;
        a_8[37].Result := 1;
        a_8[37].Method := nil;

        a_8[38].Str  := 'uti';
        a_8[38].Index := -1;
        a_8[38].Result := 1;
        a_8[38].Method := nil;

        a_8[39].Str  := 'avi';
        a_8[39].Index := -1;
        a_8[39].Result := 1;
        a_8[39].Method := nil;

        a_8[40].Str  := 'evi';
        a_8[40].Index := -1;
        a_8[40].Result := 1;
        a_8[40].Method := nil;

        a_8[41].Str  := 'ivi';
        a_8[41].Index := -1;
        a_8[41].Result := 1;
        a_8[41].Method := nil;

        a_8[42].Str  := 'isco';
        a_8[42].Index := -1;
        a_8[42].Result := 1;
        a_8[42].Method := nil;

        a_8[43].Str  := 'ando';
        a_8[43].Index := -1;
        a_8[43].Result := 1;
        a_8[43].Method := nil;

        a_8[44].Str  := 'endo';
        a_8[44].Index := -1;
        a_8[44].Result := 1;
        a_8[44].Method := nil;

        a_8[45].Str  := 'Yamo';
        a_8[45].Index := -1;
        a_8[45].Result := 1;
        a_8[45].Method := nil;

        a_8[46].Str  := 'iamo';
        a_8[46].Index := -1;
        a_8[46].Result := 1;
        a_8[46].Method := nil;

        a_8[47].Str  := 'avamo';
        a_8[47].Index := -1;
        a_8[47].Result := 1;
        a_8[47].Method := nil;

        a_8[48].Str  := 'evamo';
        a_8[48].Index := -1;
        a_8[48].Result := 1;
        a_8[48].Method := nil;

        a_8[49].Str  := 'ivamo';
        a_8[49].Index := -1;
        a_8[49].Result := 1;
        a_8[49].Method := nil;

        a_8[50].Str  := 'eremo';
        a_8[50].Index := -1;
        a_8[50].Result := 1;
        a_8[50].Method := nil;

        a_8[51].Str  := 'iremo';
        a_8[51].Index := -1;
        a_8[51].Result := 1;
        a_8[51].Method := nil;

        a_8[52].Str  := 'assimo';
        a_8[52].Index := -1;
        a_8[52].Result := 1;
        a_8[52].Method := nil;

        a_8[53].Str  := 'ammo';
        a_8[53].Index := -1;
        a_8[53].Result := 1;
        a_8[53].Method := nil;

        a_8[54].Str  := 'emmo';
        a_8[54].Index := -1;
        a_8[54].Result := 1;
        a_8[54].Method := nil;

        a_8[55].Str  := 'eremmo';
        a_8[55].Index := 54;
        a_8[55].Result := 1;
        a_8[55].Method := nil;

        a_8[56].Str  := 'iremmo';
        a_8[56].Index := 54;
        a_8[56].Result := 1;
        a_8[56].Method := nil;

        a_8[57].Str  := 'immo';
        a_8[57].Index := -1;
        a_8[57].Result := 1;
        a_8[57].Method := nil;

        a_8[58].Str  := 'ano';
        a_8[58].Index := -1;
        a_8[58].Result := 1;
        a_8[58].Method := nil;

        a_8[59].Str  := 'iscano';
        a_8[59].Index := 58;
        a_8[59].Result := 1;
        a_8[59].Method := nil;

        a_8[60].Str  := 'avano';
        a_8[60].Index := 58;
        a_8[60].Result := 1;
        a_8[60].Method := nil;

        a_8[61].Str  := 'evano';
        a_8[61].Index := 58;
        a_8[61].Result := 1;
        a_8[61].Method := nil;

        a_8[62].Str  := 'ivano';
        a_8[62].Index := 58;
        a_8[62].Result := 1;
        a_8[62].Method := nil;

        a_8[63].Str  := 'eranno';
        a_8[63].Index := -1;
        a_8[63].Result := 1;
        a_8[63].Method := nil;

        a_8[64].Str  := 'iranno';
        a_8[64].Index := -1;
        a_8[64].Result := 1;
        a_8[64].Method := nil;

        a_8[65].Str  := 'ono';
        a_8[65].Index := -1;
        a_8[65].Result := 1;
        a_8[65].Method := nil;

        a_8[66].Str  := 'iscono';
        a_8[66].Index := 65;
        a_8[66].Result := 1;
        a_8[66].Method := nil;

        a_8[67].Str  := 'arono';
        a_8[67].Index := 65;
        a_8[67].Result := 1;
        a_8[67].Method := nil;

        a_8[68].Str  := 'erono';
        a_8[68].Index := 65;
        a_8[68].Result := 1;
        a_8[68].Method := nil;

        a_8[69].Str  := 'irono';
        a_8[69].Index := 65;
        a_8[69].Result := 1;
        a_8[69].Method := nil;

        a_8[70].Str  := 'erebbero';
        a_8[70].Index := -1;
        a_8[70].Result := 1;
        a_8[70].Method := nil;

        a_8[71].Str  := 'irebbero';
        a_8[71].Index := -1;
        a_8[71].Result := 1;
        a_8[71].Method := nil;

        a_8[72].Str  := 'assero';
        a_8[72].Index := -1;
        a_8[72].Result := 1;
        a_8[72].Method := nil;

        a_8[73].Str  := 'essero';
        a_8[73].Index := -1;
        a_8[73].Result := 1;
        a_8[73].Method := nil;

        a_8[74].Str  := 'issero';
        a_8[74].Index := -1;
        a_8[74].Result := 1;
        a_8[74].Method := nil;

        a_8[75].Str  := 'ato';
        a_8[75].Index := -1;
        a_8[75].Result := 1;
        a_8[75].Method := nil;

        a_8[76].Str  := 'ito';
        a_8[76].Index := -1;
        a_8[76].Result := 1;
        a_8[76].Method := nil;

        a_8[77].Str  := 'uto';
        a_8[77].Index := -1;
        a_8[77].Result := 1;
        a_8[77].Method := nil;

        a_8[78].Str  := 'avo';
        a_8[78].Index := -1;
        a_8[78].Result := 1;
        a_8[78].Method := nil;

        a_8[79].Str  := 'evo';
        a_8[79].Index := -1;
        a_8[79].Result := 1;
        a_8[79].Method := nil;

        a_8[80].Str  := 'ivo';
        a_8[80].Index := -1;
        a_8[80].Result := 1;
        a_8[80].Method := nil;

        a_8[81].Str  := 'ar';
        a_8[81].Index := -1;
        a_8[81].Result := 1;
        a_8[81].Method := nil;

        a_8[82].Str  := 'ir';
        a_8[82].Index := -1;
        a_8[82].Result := 1;
        a_8[82].Method := nil;

        a_8[83].Str  := 'er'#224;
        a_8[83].Index := -1;
        a_8[83].Result := 1;
        a_8[83].Method := nil;

        a_8[84].Str  := 'ir'#224;
        a_8[84].Index := -1;
        a_8[84].Result := 1;
        a_8[84].Method := nil;

        a_8[85].Str  := 'er'#242;
        a_8[85].Index := -1;
        a_8[85].Result := 1;
        a_8[85].Method := nil;

        a_8[86].Str  := 'ir'#242;
        a_8[86].Index := -1;
        a_8[86].Result := 1;
        a_8[86].Method := nil;

End;

Function TItalianStemmer.stem : Boolean;
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
    lab27;
Begin
    v_1 := FCursor;
    FBra := FCursor;
    If (FindAmong(a_0, 16) = 0) Then
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
    v_3 := FCursor;
lab2:
    Begin
        v_4 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_1, 7);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom(#224);
            End;
            2:
            Begin
                SliceFrom(#232);
            End;
            3:
            Begin
                SliceFrom(#236);
            End;
            4:
            Begin
                SliceFrom(#242);
            End;
            5:
            Begin
                SliceFrom(#249);
            End;
            6:
            Begin
                SliceFrom('qU');
            End;
            7:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab3;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab2;
lab3:
        FCursor := v_4;
    End;
    FCursor := v_3;
lab4:
    Begin
        v_5 := FCursor;
        While True Do
        Begin
            v_6 := FCursor;
            If (Not (InGrouping(g_v, 97, 249))) Then
            Begin
                goto lab6;
            End;
            FBra := FCursor;
            Repeat
                v_7 := FCursor;
                If (Not (EqS('u'))) Then
                Begin
                    goto lab7;
                End;
                FKet := FCursor;
                If (Not (InGrouping(g_v, 97, 249))) Then
                Begin
                    goto lab7;
                End;
                SliceFrom('U');
                Break;
lab7:
                FCursor := v_7;
                If (Not (EqS('i'))) Then
                Begin
                    goto lab6;
                End;
                FKet := FCursor;
                If (Not (InGrouping(g_v, 97, 249))) Then
                Begin
                    goto lab6;
                End;
                SliceFrom('I');
            Until True;
            FCursor := v_6;
            Break;
lab6:
            FCursor := v_6;
            If (FCursor >= FLimit) Then
            Begin
                goto lab5;
            End;
            Inc(FCursor);
        End;
        goto lab4;
lab5:
        FCursor := v_5;
    End;
lab1:
    FCursor := v_2;
    I_pV := FLimit;
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_8 := FCursor;
    Repeat
        v_9 := FCursor;
        If (Not (InGrouping(g_v, 97, 249))) Then
        Begin
            goto lab10;
        End;
        Repeat
            v_10 := FCursor;
            If (Not (OutGrouping(g_v, 97, 249))) Then
            Begin
                goto lab11;
            End;
            If (Not (GoOutGrouping(g_v, 97, 249))) Then
            Begin
                goto lab11;
            End;
            Inc(FCursor);
            Break;
lab11:
            FCursor := v_10;
            If (Not (InGrouping(g_v, 97, 249))) Then
            Begin
                goto lab10;
            End;
            If (Not (GoInGrouping(g_v, 97, 249))) Then
            Begin
                goto lab10;
            End;
            Inc(FCursor);
        Until True;
        Break;
lab10:
        FCursor := v_9;
        If (Not (EqS('divan'))) Then
        Begin
            goto lab12;
        End;
        Break;
lab12:
        FCursor := v_9;
        If (Not (OutGrouping(g_v, 97, 249))) Then
        Begin
            goto lab9;
        End;
        Repeat
            v_11 := FCursor;
            If (Not (OutGrouping(g_v, 97, 249))) Then
            Begin
                goto lab13;
            End;
            If (Not (GoOutGrouping(g_v, 97, 249))) Then
            Begin
                goto lab13;
            End;
            Inc(FCursor);
            Break;
lab13:
            FCursor := v_11;
            If (Not (InGrouping(g_v, 97, 249))) Then
            Begin
                goto lab9;
            End;
            If (FCursor >= FLimit) Then
            Begin
                goto lab9;
            End;
            Inc(FCursor);
        Until True;
    Until True;
    I_pV := FCursor;
lab9:
    FCursor := v_8;
    v_12 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 249))) Then
    Begin
        goto lab14;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 249))) Then
    Begin
        goto lab14;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 249))) Then
    Begin
        goto lab14;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 249))) Then
    Begin
        goto lab14;
    End;
    Inc(FCursor);
    I_p2 := FCursor;
lab14:
    FCursor := v_12;
lab8:
    FBkLimit := FCursor; FCursor := FLimit;
    v_13 := FLimit - FCursor;
    FKet := FCursor;
    If (FindAmongBk(a_3, 37) = 0) Then
    Begin
        goto lab15;
    End;
    FBra := FCursor;
    AmongVar := FindAmongBk(a_4, 5);
    If (AmongVar = 0) Then
    Begin
        goto lab15;
    End;
    If I_pV > FCursor Then
    Begin
        goto lab15;
    End;
    Case AmongVar Of
        1:
        Begin
            SliceDel;
        End;
        2:
        Begin
            SliceFrom('e');
        End;
    End;
lab15:
    FCursor := FLimit - v_13;
    v_14 := FLimit - FCursor;
    Repeat
        v_15 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_7, 51);
        If (AmongVar = 0) Then
        Begin
            goto lab17;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
            End;
            2:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
                v_16 := FLimit - FCursor;
                FKet := FCursor;
                If (Not (EqSBk('ic'))) Then
                Begin
                    FCursor := FLimit - v_16;
                    goto lab18;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_16;
                    goto lab18;
                End;
                SliceDel;
lab18:
            End;
            3:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceFrom('log');
            End;
            4:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceFrom('u');
            End;
            5:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceFrom('ente');
            End;
            6:
            Begin
                If I_pV > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
            End;
            7:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
                v_17 := FLimit - FCursor;
                FKet := FCursor;
                AmongVar := FindAmongBk(a_5, 4);
                If (AmongVar = 0) Then
                Begin
                    FCursor := FLimit - v_17;
                    goto lab19;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_17;
                    goto lab19;
                End;
                SliceDel;
                Case AmongVar Of
                    1:
                    Begin
                        FKet := FCursor;
                        If (Not (EqSBk('at'))) Then
                        Begin
                            FCursor := FLimit - v_17;
                            goto lab19;
                        End;
                        FBra := FCursor;
                        If I_p2 > FCursor Then
                        Begin
                            FCursor := FLimit - v_17;
                            goto lab19;
                        End;
                        SliceDel;
                    End;
                End;
lab19:
            End;
            8:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
                v_18 := FLimit - FCursor;
                FKet := FCursor;
                If (FindAmongBk(a_6, 3) = 0) Then
                Begin
                    FCursor := FLimit - v_18;
                    goto lab20;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_18;
                    goto lab20;
                End;
                SliceDel;
lab20:
            End;
            9:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab17;
                End;
                SliceDel;
                v_19 := FLimit - FCursor;
                FKet := FCursor;
                If (Not (EqSBk('at'))) Then
                Begin
                    FCursor := FLimit - v_19;
                    goto lab21;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_19;
                    goto lab21;
                End;
                SliceDel;
                FKet := FCursor;
                If (Not (EqSBk('ic'))) Then
                Begin
                    FCursor := FLimit - v_19;
                    goto lab21;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_19;
                    goto lab21;
                End;
                SliceDel;
lab21:
            End;
        End;
        Break;
lab17:
        FCursor := FLimit - v_15;
        If (FCursor < I_pV) Then
        Begin
            goto lab16;
        End;
        v_20 := FBkLimit;
        FBkLimit := I_pV;
        FKet := FCursor;
        If (FindAmongBk(a_8, 87) = 0) Then
        Begin
            FBkLimit := v_20;
            goto lab16;
        End;
        FBra := FCursor;
        SliceDel;
        FBkLimit := v_20;
    Until True;
lab16:
    FCursor := FLimit - v_14;
    v_21 := FLimit - FCursor;
    v_22 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (InGroupingBk(g_AEIO, 97, 242))) Then
    Begin
        FCursor := FLimit - v_22;
        goto lab23;
    End;
    FBra := FCursor;
    If I_pV > FCursor Then
    Begin
        FCursor := FLimit - v_22;
        goto lab23;
    End;
    SliceDel;
    FKet := FCursor;
    If (Not (EqSBk('i'))) Then
    Begin
        FCursor := FLimit - v_22;
        goto lab23;
    End;
    FBra := FCursor;
    If I_pV > FCursor Then
    Begin
        FCursor := FLimit - v_22;
        goto lab23;
    End;
    SliceDel;
lab23:
    v_23 := FLimit - FCursor;
    FKet := FCursor;
    If (Not (EqSBk('h'))) Then
    Begin
        FCursor := FLimit - v_23;
        goto lab24;
    End;
    FBra := FCursor;
    If (Not (InGroupingBk(g_CG, 99, 103))) Then
    Begin
        FCursor := FLimit - v_23;
        goto lab24;
    End;
    If I_pV > FCursor Then
    Begin
        FCursor := FLimit - v_23;
        goto lab24;
    End;
    SliceDel;
lab24:
lab22:
    FCursor := FLimit - v_21;
    FCursor := FBkLimit;
    v_24 := FCursor;
lab26:
    Begin
        v_25 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_2, 3);
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
                If (FCursor >= FLimit) Then
                Begin
                    goto lab27;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab26;
lab27:
        FCursor := v_25;
    End;
lab25:
    FCursor := v_24;
    Result := True;
End;

End.
