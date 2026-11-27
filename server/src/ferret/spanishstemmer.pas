// Generated from spanish.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit SpanishStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TSpanishStemmer = Class(TSnowballProgram)
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
        Chr(1),
        Chr(17),
        Chr(4),
        Chr(10)
    );

Constructor TSpanishStemmer.Create;
Begin
    SetLength(a_0, 6);
        a_0[0].Str  := '';
        a_0[0].Index := -1;
        a_0[0].Result := 6;
        a_0[0].Method := nil;

        a_0[1].Str  := #225;
        a_0[1].Index := 0;
        a_0[1].Result := 1;
        a_0[1].Method := nil;

        a_0[2].Str  := #233;
        a_0[2].Index := 0;
        a_0[2].Result := 2;
        a_0[2].Method := nil;

        a_0[3].Str  := #237;
        a_0[3].Index := 0;
        a_0[3].Result := 3;
        a_0[3].Method := nil;

        a_0[4].Str  := #243;
        a_0[4].Index := 0;
        a_0[4].Result := 4;
        a_0[4].Method := nil;

        a_0[5].Str  := #250;
        a_0[5].Index := 0;
        a_0[5].Result := 5;
        a_0[5].Method := nil;

    SetLength(a_1, 13);
        a_1[0].Str  := 'la';
        a_1[0].Index := -1;
        a_1[0].Result := -1;
        a_1[0].Method := nil;

        a_1[1].Str  := 'sela';
        a_1[1].Index := 0;
        a_1[1].Result := -1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'le';
        a_1[2].Index := -1;
        a_1[2].Result := -1;
        a_1[2].Method := nil;

        a_1[3].Str  := 'me';
        a_1[3].Index := -1;
        a_1[3].Result := -1;
        a_1[3].Method := nil;

        a_1[4].Str  := 'se';
        a_1[4].Index := -1;
        a_1[4].Result := -1;
        a_1[4].Method := nil;

        a_1[5].Str  := 'lo';
        a_1[5].Index := -1;
        a_1[5].Result := -1;
        a_1[5].Method := nil;

        a_1[6].Str  := 'selo';
        a_1[6].Index := 5;
        a_1[6].Result := -1;
        a_1[6].Method := nil;

        a_1[7].Str  := 'las';
        a_1[7].Index := -1;
        a_1[7].Result := -1;
        a_1[7].Method := nil;

        a_1[8].Str  := 'selas';
        a_1[8].Index := 7;
        a_1[8].Result := -1;
        a_1[8].Method := nil;

        a_1[9].Str  := 'les';
        a_1[9].Index := -1;
        a_1[9].Result := -1;
        a_1[9].Method := nil;

        a_1[10].Str  := 'los';
        a_1[10].Index := -1;
        a_1[10].Result := -1;
        a_1[10].Method := nil;

        a_1[11].Str  := 'selos';
        a_1[11].Index := 10;
        a_1[11].Result := -1;
        a_1[11].Method := nil;

        a_1[12].Str  := 'nos';
        a_1[12].Index := -1;
        a_1[12].Result := -1;
        a_1[12].Method := nil;

    SetLength(a_2, 11);
        a_2[0].Str  := 'ando';
        a_2[0].Index := -1;
        a_2[0].Result := 6;
        a_2[0].Method := nil;

        a_2[1].Str  := 'iendo';
        a_2[1].Index := -1;
        a_2[1].Result := 6;
        a_2[1].Method := nil;

        a_2[2].Str  := 'yendo';
        a_2[2].Index := -1;
        a_2[2].Result := 7;
        a_2[2].Method := nil;

        a_2[3].Str  := #225'ndo';
        a_2[3].Index := -1;
        a_2[3].Result := 2;
        a_2[3].Method := nil;

        a_2[4].Str  := 'i'#233'ndo';
        a_2[4].Index := -1;
        a_2[4].Result := 1;
        a_2[4].Method := nil;

        a_2[5].Str  := 'ar';
        a_2[5].Index := -1;
        a_2[5].Result := 6;
        a_2[5].Method := nil;

        a_2[6].Str  := 'er';
        a_2[6].Index := -1;
        a_2[6].Result := 6;
        a_2[6].Method := nil;

        a_2[7].Str  := 'ir';
        a_2[7].Index := -1;
        a_2[7].Result := 6;
        a_2[7].Method := nil;

        a_2[8].Str  := #225'r';
        a_2[8].Index := -1;
        a_2[8].Result := 3;
        a_2[8].Method := nil;

        a_2[9].Str  := #233'r';
        a_2[9].Index := -1;
        a_2[9].Result := 4;
        a_2[9].Method := nil;

        a_2[10].Str  := #237'r';
        a_2[10].Index := -1;
        a_2[10].Result := 5;
        a_2[10].Method := nil;

    SetLength(a_3, 4);
        a_3[0].Str  := 'ic';
        a_3[0].Index := -1;
        a_3[0].Result := -1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'ad';
        a_3[1].Index := -1;
        a_3[1].Result := -1;
        a_3[1].Method := nil;

        a_3[2].Str  := 'os';
        a_3[2].Index := -1;
        a_3[2].Result := -1;
        a_3[2].Method := nil;

        a_3[3].Str  := 'iv';
        a_3[3].Index := -1;
        a_3[3].Result := 1;
        a_3[3].Method := nil;

    SetLength(a_4, 3);
        a_4[0].Str  := 'able';
        a_4[0].Index := -1;
        a_4[0].Result := 1;
        a_4[0].Method := nil;

        a_4[1].Str  := 'ible';
        a_4[1].Index := -1;
        a_4[1].Result := 1;
        a_4[1].Method := nil;

        a_4[2].Str  := 'ante';
        a_4[2].Index := -1;
        a_4[2].Result := 1;
        a_4[2].Method := nil;

    SetLength(a_5, 3);
        a_5[0].Str  := 'ic';
        a_5[0].Index := -1;
        a_5[0].Result := 1;
        a_5[0].Method := nil;

        a_5[1].Str  := 'abil';
        a_5[1].Index := -1;
        a_5[1].Result := 1;
        a_5[1].Method := nil;

        a_5[2].Str  := 'iv';
        a_5[2].Index := -1;
        a_5[2].Result := 1;
        a_5[2].Method := nil;

    SetLength(a_6, 48);
        a_6[0].Str  := 'ica';
        a_6[0].Index := -1;
        a_6[0].Result := 1;
        a_6[0].Method := nil;

        a_6[1].Str  := 'ancia';
        a_6[1].Index := -1;
        a_6[1].Result := 2;
        a_6[1].Method := nil;

        a_6[2].Str  := 'encia';
        a_6[2].Index := -1;
        a_6[2].Result := 5;
        a_6[2].Method := nil;

        a_6[3].Str  := 'adora';
        a_6[3].Index := -1;
        a_6[3].Result := 2;
        a_6[3].Method := nil;

        a_6[4].Str  := 'osa';
        a_6[4].Index := -1;
        a_6[4].Result := 1;
        a_6[4].Method := nil;

        a_6[5].Str  := 'ista';
        a_6[5].Index := -1;
        a_6[5].Result := 1;
        a_6[5].Method := nil;

        a_6[6].Str  := 'iva';
        a_6[6].Index := -1;
        a_6[6].Result := 9;
        a_6[6].Method := nil;

        a_6[7].Str  := 'anza';
        a_6[7].Index := -1;
        a_6[7].Result := 1;
        a_6[7].Method := nil;

        a_6[8].Str  := 'log'#237'a';
        a_6[8].Index := -1;
        a_6[8].Result := 3;
        a_6[8].Method := nil;

        a_6[9].Str  := 'idad';
        a_6[9].Index := -1;
        a_6[9].Result := 8;
        a_6[9].Method := nil;

        a_6[10].Str  := 'able';
        a_6[10].Index := -1;
        a_6[10].Result := 1;
        a_6[10].Method := nil;

        a_6[11].Str  := 'ible';
        a_6[11].Index := -1;
        a_6[11].Result := 1;
        a_6[11].Method := nil;

        a_6[12].Str  := 'ante';
        a_6[12].Index := -1;
        a_6[12].Result := 2;
        a_6[12].Method := nil;

        a_6[13].Str  := 'mente';
        a_6[13].Index := -1;
        a_6[13].Result := 7;
        a_6[13].Method := nil;

        a_6[14].Str  := 'amente';
        a_6[14].Index := 13;
        a_6[14].Result := 6;
        a_6[14].Method := nil;

        a_6[15].Str  := 'acion';
        a_6[15].Index := -1;
        a_6[15].Result := 2;
        a_6[15].Method := nil;

        a_6[16].Str  := 'ucion';
        a_6[16].Index := -1;
        a_6[16].Result := 4;
        a_6[16].Method := nil;

        a_6[17].Str  := 'aci'#243'n';
        a_6[17].Index := -1;
        a_6[17].Result := 2;
        a_6[17].Method := nil;

        a_6[18].Str  := 'uci'#243'n';
        a_6[18].Index := -1;
        a_6[18].Result := 4;
        a_6[18].Method := nil;

        a_6[19].Str  := 'ico';
        a_6[19].Index := -1;
        a_6[19].Result := 1;
        a_6[19].Method := nil;

        a_6[20].Str  := 'ismo';
        a_6[20].Index := -1;
        a_6[20].Result := 1;
        a_6[20].Method := nil;

        a_6[21].Str  := 'oso';
        a_6[21].Index := -1;
        a_6[21].Result := 1;
        a_6[21].Method := nil;

        a_6[22].Str  := 'amiento';
        a_6[22].Index := -1;
        a_6[22].Result := 1;
        a_6[22].Method := nil;

        a_6[23].Str  := 'imiento';
        a_6[23].Index := -1;
        a_6[23].Result := 1;
        a_6[23].Method := nil;

        a_6[24].Str  := 'ivo';
        a_6[24].Index := -1;
        a_6[24].Result := 9;
        a_6[24].Method := nil;

        a_6[25].Str  := 'ador';
        a_6[25].Index := -1;
        a_6[25].Result := 2;
        a_6[25].Method := nil;

        a_6[26].Str  := 'icas';
        a_6[26].Index := -1;
        a_6[26].Result := 1;
        a_6[26].Method := nil;

        a_6[27].Str  := 'ancias';
        a_6[27].Index := -1;
        a_6[27].Result := 2;
        a_6[27].Method := nil;

        a_6[28].Str  := 'encias';
        a_6[28].Index := -1;
        a_6[28].Result := 5;
        a_6[28].Method := nil;

        a_6[29].Str  := 'adoras';
        a_6[29].Index := -1;
        a_6[29].Result := 2;
        a_6[29].Method := nil;

        a_6[30].Str  := 'osas';
        a_6[30].Index := -1;
        a_6[30].Result := 1;
        a_6[30].Method := nil;

        a_6[31].Str  := 'istas';
        a_6[31].Index := -1;
        a_6[31].Result := 1;
        a_6[31].Method := nil;

        a_6[32].Str  := 'ivas';
        a_6[32].Index := -1;
        a_6[32].Result := 9;
        a_6[32].Method := nil;

        a_6[33].Str  := 'anzas';
        a_6[33].Index := -1;
        a_6[33].Result := 1;
        a_6[33].Method := nil;

        a_6[34].Str  := 'log'#237'as';
        a_6[34].Index := -1;
        a_6[34].Result := 3;
        a_6[34].Method := nil;

        a_6[35].Str  := 'idades';
        a_6[35].Index := -1;
        a_6[35].Result := 8;
        a_6[35].Method := nil;

        a_6[36].Str  := 'ables';
        a_6[36].Index := -1;
        a_6[36].Result := 1;
        a_6[36].Method := nil;

        a_6[37].Str  := 'ibles';
        a_6[37].Index := -1;
        a_6[37].Result := 1;
        a_6[37].Method := nil;

        a_6[38].Str  := 'aciones';
        a_6[38].Index := -1;
        a_6[38].Result := 2;
        a_6[38].Method := nil;

        a_6[39].Str  := 'uciones';
        a_6[39].Index := -1;
        a_6[39].Result := 4;
        a_6[39].Method := nil;

        a_6[40].Str  := 'adores';
        a_6[40].Index := -1;
        a_6[40].Result := 2;
        a_6[40].Method := nil;

        a_6[41].Str  := 'antes';
        a_6[41].Index := -1;
        a_6[41].Result := 2;
        a_6[41].Method := nil;

        a_6[42].Str  := 'icos';
        a_6[42].Index := -1;
        a_6[42].Result := 1;
        a_6[42].Method := nil;

        a_6[43].Str  := 'ismos';
        a_6[43].Index := -1;
        a_6[43].Result := 1;
        a_6[43].Method := nil;

        a_6[44].Str  := 'osos';
        a_6[44].Index := -1;
        a_6[44].Result := 1;
        a_6[44].Method := nil;

        a_6[45].Str  := 'amientos';
        a_6[45].Index := -1;
        a_6[45].Result := 1;
        a_6[45].Method := nil;

        a_6[46].Str  := 'imientos';
        a_6[46].Index := -1;
        a_6[46].Result := 1;
        a_6[46].Method := nil;

        a_6[47].Str  := 'ivos';
        a_6[47].Index := -1;
        a_6[47].Result := 9;
        a_6[47].Method := nil;

    SetLength(a_7, 12);
        a_7[0].Str  := 'ya';
        a_7[0].Index := -1;
        a_7[0].Result := 1;
        a_7[0].Method := nil;

        a_7[1].Str  := 'ye';
        a_7[1].Index := -1;
        a_7[1].Result := 1;
        a_7[1].Method := nil;

        a_7[2].Str  := 'yan';
        a_7[2].Index := -1;
        a_7[2].Result := 1;
        a_7[2].Method := nil;

        a_7[3].Str  := 'yen';
        a_7[3].Index := -1;
        a_7[3].Result := 1;
        a_7[3].Method := nil;

        a_7[4].Str  := 'yeron';
        a_7[4].Index := -1;
        a_7[4].Result := 1;
        a_7[4].Method := nil;

        a_7[5].Str  := 'yendo';
        a_7[5].Index := -1;
        a_7[5].Result := 1;
        a_7[5].Method := nil;

        a_7[6].Str  := 'yo';
        a_7[6].Index := -1;
        a_7[6].Result := 1;
        a_7[6].Method := nil;

        a_7[7].Str  := 'yas';
        a_7[7].Index := -1;
        a_7[7].Result := 1;
        a_7[7].Method := nil;

        a_7[8].Str  := 'yes';
        a_7[8].Index := -1;
        a_7[8].Result := 1;
        a_7[8].Method := nil;

        a_7[9].Str  := 'yais';
        a_7[9].Index := -1;
        a_7[9].Result := 1;
        a_7[9].Method := nil;

        a_7[10].Str  := 'yamos';
        a_7[10].Index := -1;
        a_7[10].Result := 1;
        a_7[10].Method := nil;

        a_7[11].Str  := 'y'#243;
        a_7[11].Index := -1;
        a_7[11].Result := 1;
        a_7[11].Method := nil;

    SetLength(a_8, 96);
        a_8[0].Str  := 'aba';
        a_8[0].Index := -1;
        a_8[0].Result := 2;
        a_8[0].Method := nil;

        a_8[1].Str  := 'ada';
        a_8[1].Index := -1;
        a_8[1].Result := 2;
        a_8[1].Method := nil;

        a_8[2].Str  := 'ida';
        a_8[2].Index := -1;
        a_8[2].Result := 2;
        a_8[2].Method := nil;

        a_8[3].Str  := 'ara';
        a_8[3].Index := -1;
        a_8[3].Result := 2;
        a_8[3].Method := nil;

        a_8[4].Str  := 'iera';
        a_8[4].Index := -1;
        a_8[4].Result := 2;
        a_8[4].Method := nil;

        a_8[5].Str  := #237'a';
        a_8[5].Index := -1;
        a_8[5].Result := 2;
        a_8[5].Method := nil;

        a_8[6].Str  := 'ar'#237'a';
        a_8[6].Index := 5;
        a_8[6].Result := 2;
        a_8[6].Method := nil;

        a_8[7].Str  := 'er'#237'a';
        a_8[7].Index := 5;
        a_8[7].Result := 2;
        a_8[7].Method := nil;

        a_8[8].Str  := 'ir'#237'a';
        a_8[8].Index := 5;
        a_8[8].Result := 2;
        a_8[8].Method := nil;

        a_8[9].Str  := 'ad';
        a_8[9].Index := -1;
        a_8[9].Result := 2;
        a_8[9].Method := nil;

        a_8[10].Str  := 'ed';
        a_8[10].Index := -1;
        a_8[10].Result := 2;
        a_8[10].Method := nil;

        a_8[11].Str  := 'id';
        a_8[11].Index := -1;
        a_8[11].Result := 2;
        a_8[11].Method := nil;

        a_8[12].Str  := 'ase';
        a_8[12].Index := -1;
        a_8[12].Result := 2;
        a_8[12].Method := nil;

        a_8[13].Str  := 'iese';
        a_8[13].Index := -1;
        a_8[13].Result := 2;
        a_8[13].Method := nil;

        a_8[14].Str  := 'aste';
        a_8[14].Index := -1;
        a_8[14].Result := 2;
        a_8[14].Method := nil;

        a_8[15].Str  := 'iste';
        a_8[15].Index := -1;
        a_8[15].Result := 2;
        a_8[15].Method := nil;

        a_8[16].Str  := 'an';
        a_8[16].Index := -1;
        a_8[16].Result := 2;
        a_8[16].Method := nil;

        a_8[17].Str  := 'aban';
        a_8[17].Index := 16;
        a_8[17].Result := 2;
        a_8[17].Method := nil;

        a_8[18].Str  := 'aran';
        a_8[18].Index := 16;
        a_8[18].Result := 2;
        a_8[18].Method := nil;

        a_8[19].Str  := 'ieran';
        a_8[19].Index := 16;
        a_8[19].Result := 2;
        a_8[19].Method := nil;

        a_8[20].Str  := #237'an';
        a_8[20].Index := 16;
        a_8[20].Result := 2;
        a_8[20].Method := nil;

        a_8[21].Str  := 'ar'#237'an';
        a_8[21].Index := 20;
        a_8[21].Result := 2;
        a_8[21].Method := nil;

        a_8[22].Str  := 'er'#237'an';
        a_8[22].Index := 20;
        a_8[22].Result := 2;
        a_8[22].Method := nil;

        a_8[23].Str  := 'ir'#237'an';
        a_8[23].Index := 20;
        a_8[23].Result := 2;
        a_8[23].Method := nil;

        a_8[24].Str  := 'en';
        a_8[24].Index := -1;
        a_8[24].Result := 1;
        a_8[24].Method := nil;

        a_8[25].Str  := 'asen';
        a_8[25].Index := 24;
        a_8[25].Result := 2;
        a_8[25].Method := nil;

        a_8[26].Str  := 'iesen';
        a_8[26].Index := 24;
        a_8[26].Result := 2;
        a_8[26].Method := nil;

        a_8[27].Str  := 'aron';
        a_8[27].Index := -1;
        a_8[27].Result := 2;
        a_8[27].Method := nil;

        a_8[28].Str  := 'ieron';
        a_8[28].Index := -1;
        a_8[28].Result := 2;
        a_8[28].Method := nil;

        a_8[29].Str  := 'ar'#225'n';
        a_8[29].Index := -1;
        a_8[29].Result := 2;
        a_8[29].Method := nil;

        a_8[30].Str  := 'er'#225'n';
        a_8[30].Index := -1;
        a_8[30].Result := 2;
        a_8[30].Method := nil;

        a_8[31].Str  := 'ir'#225'n';
        a_8[31].Index := -1;
        a_8[31].Result := 2;
        a_8[31].Method := nil;

        a_8[32].Str  := 'ado';
        a_8[32].Index := -1;
        a_8[32].Result := 2;
        a_8[32].Method := nil;

        a_8[33].Str  := 'ido';
        a_8[33].Index := -1;
        a_8[33].Result := 2;
        a_8[33].Method := nil;

        a_8[34].Str  := 'ando';
        a_8[34].Index := -1;
        a_8[34].Result := 2;
        a_8[34].Method := nil;

        a_8[35].Str  := 'iendo';
        a_8[35].Index := -1;
        a_8[35].Result := 2;
        a_8[35].Method := nil;

        a_8[36].Str  := 'ar';
        a_8[36].Index := -1;
        a_8[36].Result := 2;
        a_8[36].Method := nil;

        a_8[37].Str  := 'er';
        a_8[37].Index := -1;
        a_8[37].Result := 2;
        a_8[37].Method := nil;

        a_8[38].Str  := 'ir';
        a_8[38].Index := -1;
        a_8[38].Result := 2;
        a_8[38].Method := nil;

        a_8[39].Str  := 'as';
        a_8[39].Index := -1;
        a_8[39].Result := 2;
        a_8[39].Method := nil;

        a_8[40].Str  := 'abas';
        a_8[40].Index := 39;
        a_8[40].Result := 2;
        a_8[40].Method := nil;

        a_8[41].Str  := 'adas';
        a_8[41].Index := 39;
        a_8[41].Result := 2;
        a_8[41].Method := nil;

        a_8[42].Str  := 'idas';
        a_8[42].Index := 39;
        a_8[42].Result := 2;
        a_8[42].Method := nil;

        a_8[43].Str  := 'aras';
        a_8[43].Index := 39;
        a_8[43].Result := 2;
        a_8[43].Method := nil;

        a_8[44].Str  := 'ieras';
        a_8[44].Index := 39;
        a_8[44].Result := 2;
        a_8[44].Method := nil;

        a_8[45].Str  := #237'as';
        a_8[45].Index := 39;
        a_8[45].Result := 2;
        a_8[45].Method := nil;

        a_8[46].Str  := 'ar'#237'as';
        a_8[46].Index := 45;
        a_8[46].Result := 2;
        a_8[46].Method := nil;

        a_8[47].Str  := 'er'#237'as';
        a_8[47].Index := 45;
        a_8[47].Result := 2;
        a_8[47].Method := nil;

        a_8[48].Str  := 'ir'#237'as';
        a_8[48].Index := 45;
        a_8[48].Result := 2;
        a_8[48].Method := nil;

        a_8[49].Str  := 'es';
        a_8[49].Index := -1;
        a_8[49].Result := 1;
        a_8[49].Method := nil;

        a_8[50].Str  := 'ases';
        a_8[50].Index := 49;
        a_8[50].Result := 2;
        a_8[50].Method := nil;

        a_8[51].Str  := 'ieses';
        a_8[51].Index := 49;
        a_8[51].Result := 2;
        a_8[51].Method := nil;

        a_8[52].Str  := 'abais';
        a_8[52].Index := -1;
        a_8[52].Result := 2;
        a_8[52].Method := nil;

        a_8[53].Str  := 'arais';
        a_8[53].Index := -1;
        a_8[53].Result := 2;
        a_8[53].Method := nil;

        a_8[54].Str  := 'ierais';
        a_8[54].Index := -1;
        a_8[54].Result := 2;
        a_8[54].Method := nil;

        a_8[55].Str  := #237'ais';
        a_8[55].Index := -1;
        a_8[55].Result := 2;
        a_8[55].Method := nil;

        a_8[56].Str  := 'ar'#237'ais';
        a_8[56].Index := 55;
        a_8[56].Result := 2;
        a_8[56].Method := nil;

        a_8[57].Str  := 'er'#237'ais';
        a_8[57].Index := 55;
        a_8[57].Result := 2;
        a_8[57].Method := nil;

        a_8[58].Str  := 'ir'#237'ais';
        a_8[58].Index := 55;
        a_8[58].Result := 2;
        a_8[58].Method := nil;

        a_8[59].Str  := 'aseis';
        a_8[59].Index := -1;
        a_8[59].Result := 2;
        a_8[59].Method := nil;

        a_8[60].Str  := 'ieseis';
        a_8[60].Index := -1;
        a_8[60].Result := 2;
        a_8[60].Method := nil;

        a_8[61].Str  := 'asteis';
        a_8[61].Index := -1;
        a_8[61].Result := 2;
        a_8[61].Method := nil;

        a_8[62].Str  := 'isteis';
        a_8[62].Index := -1;
        a_8[62].Result := 2;
        a_8[62].Method := nil;

        a_8[63].Str  := #225'is';
        a_8[63].Index := -1;
        a_8[63].Result := 2;
        a_8[63].Method := nil;

        a_8[64].Str  := #233'is';
        a_8[64].Index := -1;
        a_8[64].Result := 1;
        a_8[64].Method := nil;

        a_8[65].Str  := 'ar'#233'is';
        a_8[65].Index := 64;
        a_8[65].Result := 2;
        a_8[65].Method := nil;

        a_8[66].Str  := 'er'#233'is';
        a_8[66].Index := 64;
        a_8[66].Result := 2;
        a_8[66].Method := nil;

        a_8[67].Str  := 'ir'#233'is';
        a_8[67].Index := 64;
        a_8[67].Result := 2;
        a_8[67].Method := nil;

        a_8[68].Str  := 'ados';
        a_8[68].Index := -1;
        a_8[68].Result := 2;
        a_8[68].Method := nil;

        a_8[69].Str  := 'idos';
        a_8[69].Index := -1;
        a_8[69].Result := 2;
        a_8[69].Method := nil;

        a_8[70].Str  := 'amos';
        a_8[70].Index := -1;
        a_8[70].Result := 2;
        a_8[70].Method := nil;

        a_8[71].Str  := #225'bamos';
        a_8[71].Index := 70;
        a_8[71].Result := 2;
        a_8[71].Method := nil;

        a_8[72].Str  := #225'ramos';
        a_8[72].Index := 70;
        a_8[72].Result := 2;
        a_8[72].Method := nil;

        a_8[73].Str  := 'i'#233'ramos';
        a_8[73].Index := 70;
        a_8[73].Result := 2;
        a_8[73].Method := nil;

        a_8[74].Str  := #237'amos';
        a_8[74].Index := 70;
        a_8[74].Result := 2;
        a_8[74].Method := nil;

        a_8[75].Str  := 'ar'#237'amos';
        a_8[75].Index := 74;
        a_8[75].Result := 2;
        a_8[75].Method := nil;

        a_8[76].Str  := 'er'#237'amos';
        a_8[76].Index := 74;
        a_8[76].Result := 2;
        a_8[76].Method := nil;

        a_8[77].Str  := 'ir'#237'amos';
        a_8[77].Index := 74;
        a_8[77].Result := 2;
        a_8[77].Method := nil;

        a_8[78].Str  := 'emos';
        a_8[78].Index := -1;
        a_8[78].Result := 1;
        a_8[78].Method := nil;

        a_8[79].Str  := 'aremos';
        a_8[79].Index := 78;
        a_8[79].Result := 2;
        a_8[79].Method := nil;

        a_8[80].Str  := 'eremos';
        a_8[80].Index := 78;
        a_8[80].Result := 2;
        a_8[80].Method := nil;

        a_8[81].Str  := 'iremos';
        a_8[81].Index := 78;
        a_8[81].Result := 2;
        a_8[81].Method := nil;

        a_8[82].Str  := #225'semos';
        a_8[82].Index := 78;
        a_8[82].Result := 2;
        a_8[82].Method := nil;

        a_8[83].Str  := 'i'#233'semos';
        a_8[83].Index := 78;
        a_8[83].Result := 2;
        a_8[83].Method := nil;

        a_8[84].Str  := 'imos';
        a_8[84].Index := -1;
        a_8[84].Result := 2;
        a_8[84].Method := nil;

        a_8[85].Str  := 'ar'#225's';
        a_8[85].Index := -1;
        a_8[85].Result := 2;
        a_8[85].Method := nil;

        a_8[86].Str  := 'er'#225's';
        a_8[86].Index := -1;
        a_8[86].Result := 2;
        a_8[86].Method := nil;

        a_8[87].Str  := 'ir'#225's';
        a_8[87].Index := -1;
        a_8[87].Result := 2;
        a_8[87].Method := nil;

        a_8[88].Str  := #237's';
        a_8[88].Index := -1;
        a_8[88].Result := 2;
        a_8[88].Method := nil;

        a_8[89].Str  := 'ar'#225;
        a_8[89].Index := -1;
        a_8[89].Result := 2;
        a_8[89].Method := nil;

        a_8[90].Str  := 'er'#225;
        a_8[90].Index := -1;
        a_8[90].Result := 2;
        a_8[90].Method := nil;

        a_8[91].Str  := 'ir'#225;
        a_8[91].Index := -1;
        a_8[91].Result := 2;
        a_8[91].Method := nil;

        a_8[92].Str  := 'ar'#233;
        a_8[92].Index := -1;
        a_8[92].Result := 2;
        a_8[92].Method := nil;

        a_8[93].Str  := 'er'#233;
        a_8[93].Index := -1;
        a_8[93].Result := 2;
        a_8[93].Method := nil;

        a_8[94].Str  := 'ir'#233;
        a_8[94].Index := -1;
        a_8[94].Result := 2;
        a_8[94].Method := nil;

        a_8[95].Str  := 'i'#243;
        a_8[95].Index := -1;
        a_8[95].Result := 2;
        a_8[95].Method := nil;

    SetLength(a_9, 8);
        a_9[0].Str  := 'a';
        a_9[0].Index := -1;
        a_9[0].Result := 1;
        a_9[0].Method := nil;

        a_9[1].Str  := 'e';
        a_9[1].Index := -1;
        a_9[1].Result := 2;
        a_9[1].Method := nil;

        a_9[2].Str  := 'o';
        a_9[2].Index := -1;
        a_9[2].Result := 1;
        a_9[2].Method := nil;

        a_9[3].Str  := 'os';
        a_9[3].Index := -1;
        a_9[3].Result := 1;
        a_9[3].Method := nil;

        a_9[4].Str  := #225;
        a_9[4].Index := -1;
        a_9[4].Result := 1;
        a_9[4].Method := nil;

        a_9[5].Str  := #233;
        a_9[5].Index := -1;
        a_9[5].Result := 2;
        a_9[5].Method := nil;

        a_9[6].Str  := #237;
        a_9[6].Index := -1;
        a_9[6].Result := 1;
        a_9[6].Method := nil;

        a_9[7].Str  := #243;
        a_9[7].Index := -1;
        a_9[7].Result := 1;
        a_9[7].Method := nil;

End;

Function TSpanishStemmer.stem : Boolean;
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
    lab20;
Begin
    I_pV := FLimit;
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_1 := FCursor;
    Repeat
        v_2 := FCursor;
        If (Not (InGrouping(g_v, 97, 252))) Then
        Begin
            goto lab2;
        End;
        Repeat
            v_3 := FCursor;
            If (Not (OutGrouping(g_v, 97, 252))) Then
            Begin
                goto lab3;
            End;
            If (Not (GoOutGrouping(g_v, 97, 252))) Then
            Begin
                goto lab3;
            End;
            Inc(FCursor);
            Break;
lab3:
            FCursor := v_3;
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab2;
            End;
            If (Not (GoInGrouping(g_v, 97, 252))) Then
            Begin
                goto lab2;
            End;
            Inc(FCursor);
        Until True;
        Break;
lab2:
        FCursor := v_2;
        If (Not (OutGrouping(g_v, 97, 252))) Then
        Begin
            goto lab1;
        End;
        Repeat
            v_4 := FCursor;
            If (Not (OutGrouping(g_v, 97, 252))) Then
            Begin
                goto lab4;
            End;
            If (Not (GoOutGrouping(g_v, 97, 252))) Then
            Begin
                goto lab4;
            End;
            Inc(FCursor);
            Break;
lab4:
            FCursor := v_4;
            If (Not (InGrouping(g_v, 97, 252))) Then
            Begin
                goto lab1;
            End;
            If (FCursor >= FLimit) Then
            Begin
                goto lab1;
            End;
            Inc(FCursor);
        Until True;
    Until True;
    I_pV := FCursor;
lab1:
    FCursor := v_1;
    v_5 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab5;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 252))) Then
    Begin
        goto lab5;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 252))) Then
    Begin
        goto lab5;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 252))) Then
    Begin
        goto lab5;
    End;
    Inc(FCursor);
    I_p2 := FCursor;
lab5:
    FCursor := v_5;
lab0:
    FBkLimit := FCursor; FCursor := FLimit;
    v_6 := FLimit - FCursor;
    FKet := FCursor;
    If (FindAmongBk(a_1, 13) = 0) Then
    Begin
        goto lab6;
    End;
    FBra := FCursor;
    AmongVar := FindAmongBk(a_2, 11);
    If (AmongVar = 0) Then
    Begin
        goto lab6;
    End;
    If I_pV > FCursor Then
    Begin
        goto lab6;
    End;
    Case AmongVar Of
        1:
        Begin
            FBra := FCursor;
            SliceFrom('iendo');
        End;
        2:
        Begin
            FBra := FCursor;
            SliceFrom('ando');
        End;
        3:
        Begin
            FBra := FCursor;
            SliceFrom('ar');
        End;
        4:
        Begin
            FBra := FCursor;
            SliceFrom('er');
        End;
        5:
        Begin
            FBra := FCursor;
            SliceFrom('ir');
        End;
        6:
        Begin
            SliceDel;
        End;
        7:
        Begin
            If (Not (EqSBk('u'))) Then
            Begin
                goto lab6;
            End;
            SliceDel;
        End;
    End;
lab6:
    FCursor := FLimit - v_6;
    v_7 := FLimit - FCursor;
    Repeat
        v_8 := FLimit - FCursor;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_6, 48);
        If (AmongVar = 0) Then
        Begin
            goto lab8;
        End;
        FBra := FCursor;
        Case AmongVar Of
            1:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
            End;
            2:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
                v_9 := FLimit - FCursor;
                FKet := FCursor;
                If (Not (EqSBk('ic'))) Then
                Begin
                    FCursor := FLimit - v_9;
                    goto lab9;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_9;
                    goto lab9;
                End;
                SliceDel;
lab9:
            End;
            3:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceFrom('log');
            End;
            4:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceFrom('u');
            End;
            5:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceFrom('ente');
            End;
            6:
            Begin
                If I_p1 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
                v_10 := FLimit - FCursor;
                FKet := FCursor;
                AmongVar := FindAmongBk(a_3, 4);
                If (AmongVar = 0) Then
                Begin
                    FCursor := FLimit - v_10;
                    goto lab10;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_10;
                    goto lab10;
                End;
                SliceDel;
                Case AmongVar Of
                    1:
                    Begin
                        FKet := FCursor;
                        If (Not (EqSBk('at'))) Then
                        Begin
                            FCursor := FLimit - v_10;
                            goto lab10;
                        End;
                        FBra := FCursor;
                        If I_p2 > FCursor Then
                        Begin
                            FCursor := FLimit - v_10;
                            goto lab10;
                        End;
                        SliceDel;
                    End;
                End;
lab10:
            End;
            7:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
                v_11 := FLimit - FCursor;
                FKet := FCursor;
                If (FindAmongBk(a_4, 3) = 0) Then
                Begin
                    FCursor := FLimit - v_11;
                    goto lab11;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_11;
                    goto lab11;
                End;
                SliceDel;
lab11:
            End;
            8:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
                v_12 := FLimit - FCursor;
                FKet := FCursor;
                If (FindAmongBk(a_5, 3) = 0) Then
                Begin
                    FCursor := FLimit - v_12;
                    goto lab12;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_12;
                    goto lab12;
                End;
                SliceDel;
lab12:
            End;
            9:
            Begin
                If I_p2 > FCursor Then
                Begin
                    goto lab8;
                End;
                SliceDel;
                v_13 := FLimit - FCursor;
                FKet := FCursor;
                If (Not (EqSBk('at'))) Then
                Begin
                    FCursor := FLimit - v_13;
                    goto lab13;
                End;
                FBra := FCursor;
                If I_p2 > FCursor Then
                Begin
                    FCursor := FLimit - v_13;
                    goto lab13;
                End;
                SliceDel;
lab13:
            End;
        End;
        Break;
lab8:
        FCursor := FLimit - v_8;
        If (FCursor < I_pV) Then
        Begin
            goto lab14;
        End;
        v_14 := FBkLimit;
        FBkLimit := I_pV;
        FKet := FCursor;
        If (FindAmongBk(a_7, 12) = 0) Then
        Begin
            FBkLimit := v_14;
            goto lab14;
        End;
        FBra := FCursor;
        FBkLimit := v_14;
        If (Not (EqSBk('u'))) Then
        Begin
            goto lab14;
        End;
        SliceDel;
        Break;
lab14:
        FCursor := FLimit - v_8;
        If (FCursor < I_pV) Then
        Begin
            goto lab7;
        End;
        v_15 := FBkLimit;
        FBkLimit := I_pV;
        FKet := FCursor;
        AmongVar := FindAmongBk(a_8, 96);
        If (AmongVar = 0) Then
        Begin
            FBkLimit := v_15;
            goto lab7;
        End;
        FBra := FCursor;
        FBkLimit := v_15;
        Case AmongVar Of
            1:
            Begin
                v_16 := FLimit - FCursor;
                If (Not (EqSBk('u'))) Then
                Begin
                    FCursor := FLimit - v_16;
                    goto lab15;
                End;
                v_17 := FLimit - FCursor;
                If (Not (EqSBk('g'))) Then
                Begin
                    FCursor := FLimit - v_16;
                    goto lab15;
                End;
                FCursor := FLimit - v_17;
lab15:
                FBra := FCursor;
                SliceDel;
            End;
            2:
            Begin
                SliceDel;
            End;
        End;
    Until True;
lab7:
    FCursor := FLimit - v_7;
    v_18 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_9, 8);
    If (AmongVar = 0) Then
    Begin
        goto lab16;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            If I_pV > FCursor Then
            Begin
                goto lab16;
            End;
            SliceDel;
        End;
        2:
        Begin
            If I_pV > FCursor Then
            Begin
                goto lab16;
            End;
            SliceDel;
            v_19 := FLimit - FCursor;
            FKet := FCursor;
            If (Not (EqSBk('u'))) Then
            Begin
                FCursor := FLimit - v_19;
                goto lab17;
            End;
            FBra := FCursor;
            v_20 := FLimit - FCursor;
            If (Not (EqSBk('g'))) Then
            Begin
                FCursor := FLimit - v_19;
                goto lab17;
            End;
            FCursor := FLimit - v_20;
            If I_pV > FCursor Then
            Begin
                FCursor := FLimit - v_19;
                goto lab17;
            End;
            SliceDel;
lab17:
        End;
    End;
lab16:
    FCursor := FLimit - v_18;
    FCursor := FBkLimit;
    v_21 := FCursor;
lab19:
    Begin
        v_22 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_0, 6);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('a');
            End;
            2:
            Begin
                SliceFrom('e');
            End;
            3:
            Begin
                SliceFrom('i');
            End;
            4:
            Begin
                SliceFrom('o');
            End;
            5:
            Begin
                SliceFrom('u');
            End;
            6:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab20;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab19;
lab20:
        FCursor := v_22;
    End;
lab18:
    FCursor := v_21;
    Result := True;
End;

End.
