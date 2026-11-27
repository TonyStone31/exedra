// Generated from portuguese.sbl by Snowball 3.2.0 - https://snowballstem.org/

Unit PortugueseStemmer;

{$mode delphi}{$H+} // Ferret: compile with Free Pascal.

{$HINTS OFF}

Interface

Uses SnowballProgram;

Type
    TPortugueseStemmer = Class(TSnowballProgram)
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
        Chr(0),
        Chr(3),
        Chr(19),
        Chr(12),
        Chr(2)
    );

Constructor TPortugueseStemmer.Create;
Begin
    SetLength(a_0, 3);
        a_0[0].Str  := '';
        a_0[0].Index := -1;
        a_0[0].Result := 3;
        a_0[0].Method := nil;

        a_0[1].Str  := #227;
        a_0[1].Index := 0;
        a_0[1].Result := 1;
        a_0[1].Method := nil;

        a_0[2].Str  := #245;
        a_0[2].Index := 0;
        a_0[2].Result := 2;
        a_0[2].Method := nil;

    SetLength(a_1, 3);
        a_1[0].Str  := '';
        a_1[0].Index := -1;
        a_1[0].Result := 3;
        a_1[0].Method := nil;

        a_1[1].Str  := 'a~';
        a_1[1].Index := 0;
        a_1[1].Result := 1;
        a_1[1].Method := nil;

        a_1[2].Str  := 'o~';
        a_1[2].Index := 0;
        a_1[2].Result := 2;
        a_1[2].Method := nil;

    SetLength(a_2, 4);
        a_2[0].Str  := 'ic';
        a_2[0].Index := -1;
        a_2[0].Result := -1;
        a_2[0].Method := nil;

        a_2[1].Str  := 'ad';
        a_2[1].Index := -1;
        a_2[1].Result := -1;
        a_2[1].Method := nil;

        a_2[2].Str  := 'os';
        a_2[2].Index := -1;
        a_2[2].Result := -1;
        a_2[2].Method := nil;

        a_2[3].Str  := 'iv';
        a_2[3].Index := -1;
        a_2[3].Result := 1;
        a_2[3].Method := nil;

    SetLength(a_3, 3);
        a_3[0].Str  := 'ante';
        a_3[0].Index := -1;
        a_3[0].Result := 1;
        a_3[0].Method := nil;

        a_3[1].Str  := 'avel';
        a_3[1].Index := -1;
        a_3[1].Result := 1;
        a_3[1].Method := nil;

        a_3[2].Str  := #237'vel';
        a_3[2].Index := -1;
        a_3[2].Result := 1;
        a_3[2].Method := nil;

    SetLength(a_4, 3);
        a_4[0].Str  := 'ic';
        a_4[0].Index := -1;
        a_4[0].Result := 1;
        a_4[0].Method := nil;

        a_4[1].Str  := 'abil';
        a_4[1].Index := -1;
        a_4[1].Result := 1;
        a_4[1].Method := nil;

        a_4[2].Str  := 'iv';
        a_4[2].Index := -1;
        a_4[2].Result := 1;
        a_4[2].Method := nil;

    SetLength(a_5, 45);
        a_5[0].Str  := 'ica';
        a_5[0].Index := -1;
        a_5[0].Result := 1;
        a_5[0].Method := nil;

        a_5[1].Str  := #226'ncia';
        a_5[1].Index := -1;
        a_5[1].Result := 1;
        a_5[1].Method := nil;

        a_5[2].Str  := #234'ncia';
        a_5[2].Index := -1;
        a_5[2].Result := 4;
        a_5[2].Method := nil;

        a_5[3].Str  := 'logia';
        a_5[3].Index := -1;
        a_5[3].Result := 2;
        a_5[3].Method := nil;

        a_5[4].Str  := 'ira';
        a_5[4].Index := -1;
        a_5[4].Result := 9;
        a_5[4].Method := nil;

        a_5[5].Str  := 'adora';
        a_5[5].Index := -1;
        a_5[5].Result := 1;
        a_5[5].Method := nil;

        a_5[6].Str  := 'osa';
        a_5[6].Index := -1;
        a_5[6].Result := 1;
        a_5[6].Method := nil;

        a_5[7].Str  := 'ista';
        a_5[7].Index := -1;
        a_5[7].Result := 1;
        a_5[7].Method := nil;

        a_5[8].Str  := 'iva';
        a_5[8].Index := -1;
        a_5[8].Result := 8;
        a_5[8].Method := nil;

        a_5[9].Str  := 'eza';
        a_5[9].Index := -1;
        a_5[9].Result := 1;
        a_5[9].Method := nil;

        a_5[10].Str  := 'idade';
        a_5[10].Index := -1;
        a_5[10].Result := 7;
        a_5[10].Method := nil;

        a_5[11].Str  := 'ante';
        a_5[11].Index := -1;
        a_5[11].Result := 1;
        a_5[11].Method := nil;

        a_5[12].Str  := 'mente';
        a_5[12].Index := -1;
        a_5[12].Result := 6;
        a_5[12].Method := nil;

        a_5[13].Str  := 'amente';
        a_5[13].Index := 12;
        a_5[13].Result := 5;
        a_5[13].Method := nil;

        a_5[14].Str  := #225'vel';
        a_5[14].Index := -1;
        a_5[14].Result := 1;
        a_5[14].Method := nil;

        a_5[15].Str  := #237'vel';
        a_5[15].Index := -1;
        a_5[15].Result := 1;
        a_5[15].Method := nil;

        a_5[16].Str  := 'ico';
        a_5[16].Index := -1;
        a_5[16].Result := 1;
        a_5[16].Method := nil;

        a_5[17].Str  := 'ismo';
        a_5[17].Index := -1;
        a_5[17].Result := 1;
        a_5[17].Method := nil;

        a_5[18].Str  := 'oso';
        a_5[18].Index := -1;
        a_5[18].Result := 1;
        a_5[18].Method := nil;

        a_5[19].Str  := 'amento';
        a_5[19].Index := -1;
        a_5[19].Result := 1;
        a_5[19].Method := nil;

        a_5[20].Str  := 'imento';
        a_5[20].Index := -1;
        a_5[20].Result := 1;
        a_5[20].Method := nil;

        a_5[21].Str  := 'ivo';
        a_5[21].Index := -1;
        a_5[21].Result := 8;
        a_5[21].Method := nil;

        a_5[22].Str  := 'a'#231'a~o';
        a_5[22].Index := -1;
        a_5[22].Result := 1;
        a_5[22].Method := nil;

        a_5[23].Str  := 'u'#231'a~o';
        a_5[23].Index := -1;
        a_5[23].Result := 3;
        a_5[23].Method := nil;

        a_5[24].Str  := 'ador';
        a_5[24].Index := -1;
        a_5[24].Result := 1;
        a_5[24].Method := nil;

        a_5[25].Str  := 'icas';
        a_5[25].Index := -1;
        a_5[25].Result := 1;
        a_5[25].Method := nil;

        a_5[26].Str  := #234'ncias';
        a_5[26].Index := -1;
        a_5[26].Result := 4;
        a_5[26].Method := nil;

        a_5[27].Str  := 'logias';
        a_5[27].Index := -1;
        a_5[27].Result := 2;
        a_5[27].Method := nil;

        a_5[28].Str  := 'iras';
        a_5[28].Index := -1;
        a_5[28].Result := 9;
        a_5[28].Method := nil;

        a_5[29].Str  := 'adoras';
        a_5[29].Index := -1;
        a_5[29].Result := 1;
        a_5[29].Method := nil;

        a_5[30].Str  := 'osas';
        a_5[30].Index := -1;
        a_5[30].Result := 1;
        a_5[30].Method := nil;

        a_5[31].Str  := 'istas';
        a_5[31].Index := -1;
        a_5[31].Result := 1;
        a_5[31].Method := nil;

        a_5[32].Str  := 'ivas';
        a_5[32].Index := -1;
        a_5[32].Result := 8;
        a_5[32].Method := nil;

        a_5[33].Str  := 'ezas';
        a_5[33].Index := -1;
        a_5[33].Result := 1;
        a_5[33].Method := nil;

        a_5[34].Str  := 'idades';
        a_5[34].Index := -1;
        a_5[34].Result := 7;
        a_5[34].Method := nil;

        a_5[35].Str  := 'adores';
        a_5[35].Index := -1;
        a_5[35].Result := 1;
        a_5[35].Method := nil;

        a_5[36].Str  := 'antes';
        a_5[36].Index := -1;
        a_5[36].Result := 1;
        a_5[36].Method := nil;

        a_5[37].Str  := 'a'#231'o~es';
        a_5[37].Index := -1;
        a_5[37].Result := 1;
        a_5[37].Method := nil;

        a_5[38].Str  := 'u'#231'o~es';
        a_5[38].Index := -1;
        a_5[38].Result := 3;
        a_5[38].Method := nil;

        a_5[39].Str  := 'icos';
        a_5[39].Index := -1;
        a_5[39].Result := 1;
        a_5[39].Method := nil;

        a_5[40].Str  := 'ismos';
        a_5[40].Index := -1;
        a_5[40].Result := 1;
        a_5[40].Method := nil;

        a_5[41].Str  := 'osos';
        a_5[41].Index := -1;
        a_5[41].Result := 1;
        a_5[41].Method := nil;

        a_5[42].Str  := 'amentos';
        a_5[42].Index := -1;
        a_5[42].Result := 1;
        a_5[42].Method := nil;

        a_5[43].Str  := 'imentos';
        a_5[43].Index := -1;
        a_5[43].Result := 1;
        a_5[43].Method := nil;

        a_5[44].Str  := 'ivos';
        a_5[44].Index := -1;
        a_5[44].Result := 8;
        a_5[44].Method := nil;

    SetLength(a_6, 120);
        a_6[0].Str  := 'ada';
        a_6[0].Index := -1;
        a_6[0].Result := 1;
        a_6[0].Method := nil;

        a_6[1].Str  := 'ida';
        a_6[1].Index := -1;
        a_6[1].Result := 1;
        a_6[1].Method := nil;

        a_6[2].Str  := 'ia';
        a_6[2].Index := -1;
        a_6[2].Result := 1;
        a_6[2].Method := nil;

        a_6[3].Str  := 'aria';
        a_6[3].Index := 2;
        a_6[3].Result := 1;
        a_6[3].Method := nil;

        a_6[4].Str  := 'eria';
        a_6[4].Index := 2;
        a_6[4].Result := 1;
        a_6[4].Method := nil;

        a_6[5].Str  := 'iria';
        a_6[5].Index := 2;
        a_6[5].Result := 1;
        a_6[5].Method := nil;

        a_6[6].Str  := 'ara';
        a_6[6].Index := -1;
        a_6[6].Result := 1;
        a_6[6].Method := nil;

        a_6[7].Str  := 'era';
        a_6[7].Index := -1;
        a_6[7].Result := 1;
        a_6[7].Method := nil;

        a_6[8].Str  := 'ira';
        a_6[8].Index := -1;
        a_6[8].Result := 1;
        a_6[8].Method := nil;

        a_6[9].Str  := 'ava';
        a_6[9].Index := -1;
        a_6[9].Result := 1;
        a_6[9].Method := nil;

        a_6[10].Str  := 'asse';
        a_6[10].Index := -1;
        a_6[10].Result := 1;
        a_6[10].Method := nil;

        a_6[11].Str  := 'esse';
        a_6[11].Index := -1;
        a_6[11].Result := 1;
        a_6[11].Method := nil;

        a_6[12].Str  := 'isse';
        a_6[12].Index := -1;
        a_6[12].Result := 1;
        a_6[12].Method := nil;

        a_6[13].Str  := 'aste';
        a_6[13].Index := -1;
        a_6[13].Result := 1;
        a_6[13].Method := nil;

        a_6[14].Str  := 'este';
        a_6[14].Index := -1;
        a_6[14].Result := 1;
        a_6[14].Method := nil;

        a_6[15].Str  := 'iste';
        a_6[15].Index := -1;
        a_6[15].Result := 1;
        a_6[15].Method := nil;

        a_6[16].Str  := 'ei';
        a_6[16].Index := -1;
        a_6[16].Result := 1;
        a_6[16].Method := nil;

        a_6[17].Str  := 'arei';
        a_6[17].Index := 16;
        a_6[17].Result := 1;
        a_6[17].Method := nil;

        a_6[18].Str  := 'erei';
        a_6[18].Index := 16;
        a_6[18].Result := 1;
        a_6[18].Method := nil;

        a_6[19].Str  := 'irei';
        a_6[19].Index := 16;
        a_6[19].Result := 1;
        a_6[19].Method := nil;

        a_6[20].Str  := 'am';
        a_6[20].Index := -1;
        a_6[20].Result := 1;
        a_6[20].Method := nil;

        a_6[21].Str  := 'iam';
        a_6[21].Index := 20;
        a_6[21].Result := 1;
        a_6[21].Method := nil;

        a_6[22].Str  := 'ariam';
        a_6[22].Index := 21;
        a_6[22].Result := 1;
        a_6[22].Method := nil;

        a_6[23].Str  := 'eriam';
        a_6[23].Index := 21;
        a_6[23].Result := 1;
        a_6[23].Method := nil;

        a_6[24].Str  := 'iriam';
        a_6[24].Index := 21;
        a_6[24].Result := 1;
        a_6[24].Method := nil;

        a_6[25].Str  := 'aram';
        a_6[25].Index := 20;
        a_6[25].Result := 1;
        a_6[25].Method := nil;

        a_6[26].Str  := 'eram';
        a_6[26].Index := 20;
        a_6[26].Result := 1;
        a_6[26].Method := nil;

        a_6[27].Str  := 'iram';
        a_6[27].Index := 20;
        a_6[27].Result := 1;
        a_6[27].Method := nil;

        a_6[28].Str  := 'avam';
        a_6[28].Index := 20;
        a_6[28].Result := 1;
        a_6[28].Method := nil;

        a_6[29].Str  := 'em';
        a_6[29].Index := -1;
        a_6[29].Result := 1;
        a_6[29].Method := nil;

        a_6[30].Str  := 'arem';
        a_6[30].Index := 29;
        a_6[30].Result := 1;
        a_6[30].Method := nil;

        a_6[31].Str  := 'erem';
        a_6[31].Index := 29;
        a_6[31].Result := 1;
        a_6[31].Method := nil;

        a_6[32].Str  := 'irem';
        a_6[32].Index := 29;
        a_6[32].Result := 1;
        a_6[32].Method := nil;

        a_6[33].Str  := 'assem';
        a_6[33].Index := 29;
        a_6[33].Result := 1;
        a_6[33].Method := nil;

        a_6[34].Str  := 'essem';
        a_6[34].Index := 29;
        a_6[34].Result := 1;
        a_6[34].Method := nil;

        a_6[35].Str  := 'issem';
        a_6[35].Index := 29;
        a_6[35].Result := 1;
        a_6[35].Method := nil;

        a_6[36].Str  := 'ado';
        a_6[36].Index := -1;
        a_6[36].Result := 1;
        a_6[36].Method := nil;

        a_6[37].Str  := 'ido';
        a_6[37].Index := -1;
        a_6[37].Result := 1;
        a_6[37].Method := nil;

        a_6[38].Str  := 'ando';
        a_6[38].Index := -1;
        a_6[38].Result := 1;
        a_6[38].Method := nil;

        a_6[39].Str  := 'endo';
        a_6[39].Index := -1;
        a_6[39].Result := 1;
        a_6[39].Method := nil;

        a_6[40].Str  := 'indo';
        a_6[40].Index := -1;
        a_6[40].Result := 1;
        a_6[40].Method := nil;

        a_6[41].Str  := 'ara~o';
        a_6[41].Index := -1;
        a_6[41].Result := 1;
        a_6[41].Method := nil;

        a_6[42].Str  := 'era~o';
        a_6[42].Index := -1;
        a_6[42].Result := 1;
        a_6[42].Method := nil;

        a_6[43].Str  := 'ira~o';
        a_6[43].Index := -1;
        a_6[43].Result := 1;
        a_6[43].Method := nil;

        a_6[44].Str  := 'ar';
        a_6[44].Index := -1;
        a_6[44].Result := 1;
        a_6[44].Method := nil;

        a_6[45].Str  := 'er';
        a_6[45].Index := -1;
        a_6[45].Result := 1;
        a_6[45].Method := nil;

        a_6[46].Str  := 'ir';
        a_6[46].Index := -1;
        a_6[46].Result := 1;
        a_6[46].Method := nil;

        a_6[47].Str  := 'as';
        a_6[47].Index := -1;
        a_6[47].Result := 1;
        a_6[47].Method := nil;

        a_6[48].Str  := 'adas';
        a_6[48].Index := 47;
        a_6[48].Result := 1;
        a_6[48].Method := nil;

        a_6[49].Str  := 'idas';
        a_6[49].Index := 47;
        a_6[49].Result := 1;
        a_6[49].Method := nil;

        a_6[50].Str  := 'ias';
        a_6[50].Index := 47;
        a_6[50].Result := 1;
        a_6[50].Method := nil;

        a_6[51].Str  := 'arias';
        a_6[51].Index := 50;
        a_6[51].Result := 1;
        a_6[51].Method := nil;

        a_6[52].Str  := 'erias';
        a_6[52].Index := 50;
        a_6[52].Result := 1;
        a_6[52].Method := nil;

        a_6[53].Str  := 'irias';
        a_6[53].Index := 50;
        a_6[53].Result := 1;
        a_6[53].Method := nil;

        a_6[54].Str  := 'aras';
        a_6[54].Index := 47;
        a_6[54].Result := 1;
        a_6[54].Method := nil;

        a_6[55].Str  := 'eras';
        a_6[55].Index := 47;
        a_6[55].Result := 1;
        a_6[55].Method := nil;

        a_6[56].Str  := 'iras';
        a_6[56].Index := 47;
        a_6[56].Result := 1;
        a_6[56].Method := nil;

        a_6[57].Str  := 'avas';
        a_6[57].Index := 47;
        a_6[57].Result := 1;
        a_6[57].Method := nil;

        a_6[58].Str  := 'es';
        a_6[58].Index := -1;
        a_6[58].Result := 1;
        a_6[58].Method := nil;

        a_6[59].Str  := 'ardes';
        a_6[59].Index := 58;
        a_6[59].Result := 1;
        a_6[59].Method := nil;

        a_6[60].Str  := 'erdes';
        a_6[60].Index := 58;
        a_6[60].Result := 1;
        a_6[60].Method := nil;

        a_6[61].Str  := 'irdes';
        a_6[61].Index := 58;
        a_6[61].Result := 1;
        a_6[61].Method := nil;

        a_6[62].Str  := 'ares';
        a_6[62].Index := 58;
        a_6[62].Result := 1;
        a_6[62].Method := nil;

        a_6[63].Str  := 'eres';
        a_6[63].Index := 58;
        a_6[63].Result := 1;
        a_6[63].Method := nil;

        a_6[64].Str  := 'ires';
        a_6[64].Index := 58;
        a_6[64].Result := 1;
        a_6[64].Method := nil;

        a_6[65].Str  := 'asses';
        a_6[65].Index := 58;
        a_6[65].Result := 1;
        a_6[65].Method := nil;

        a_6[66].Str  := 'esses';
        a_6[66].Index := 58;
        a_6[66].Result := 1;
        a_6[66].Method := nil;

        a_6[67].Str  := 'isses';
        a_6[67].Index := 58;
        a_6[67].Result := 1;
        a_6[67].Method := nil;

        a_6[68].Str  := 'astes';
        a_6[68].Index := 58;
        a_6[68].Result := 1;
        a_6[68].Method := nil;

        a_6[69].Str  := 'estes';
        a_6[69].Index := 58;
        a_6[69].Result := 1;
        a_6[69].Method := nil;

        a_6[70].Str  := 'istes';
        a_6[70].Index := 58;
        a_6[70].Result := 1;
        a_6[70].Method := nil;

        a_6[71].Str  := 'is';
        a_6[71].Index := -1;
        a_6[71].Result := 1;
        a_6[71].Method := nil;

        a_6[72].Str  := 'ais';
        a_6[72].Index := 71;
        a_6[72].Result := 1;
        a_6[72].Method := nil;

        a_6[73].Str  := 'eis';
        a_6[73].Index := 71;
        a_6[73].Result := 1;
        a_6[73].Method := nil;

        a_6[74].Str  := 'areis';
        a_6[74].Index := 73;
        a_6[74].Result := 1;
        a_6[74].Method := nil;

        a_6[75].Str  := 'ereis';
        a_6[75].Index := 73;
        a_6[75].Result := 1;
        a_6[75].Method := nil;

        a_6[76].Str  := 'ireis';
        a_6[76].Index := 73;
        a_6[76].Result := 1;
        a_6[76].Method := nil;

        a_6[77].Str  := #225'reis';
        a_6[77].Index := 73;
        a_6[77].Result := 1;
        a_6[77].Method := nil;

        a_6[78].Str  := #233'reis';
        a_6[78].Index := 73;
        a_6[78].Result := 1;
        a_6[78].Method := nil;

        a_6[79].Str  := #237'reis';
        a_6[79].Index := 73;
        a_6[79].Result := 1;
        a_6[79].Method := nil;

        a_6[80].Str  := #225'sseis';
        a_6[80].Index := 73;
        a_6[80].Result := 1;
        a_6[80].Method := nil;

        a_6[81].Str  := #233'sseis';
        a_6[81].Index := 73;
        a_6[81].Result := 1;
        a_6[81].Method := nil;

        a_6[82].Str  := #237'sseis';
        a_6[82].Index := 73;
        a_6[82].Result := 1;
        a_6[82].Method := nil;

        a_6[83].Str  := #225'veis';
        a_6[83].Index := 73;
        a_6[83].Result := 1;
        a_6[83].Method := nil;

        a_6[84].Str  := #237'eis';
        a_6[84].Index := 73;
        a_6[84].Result := 1;
        a_6[84].Method := nil;

        a_6[85].Str  := 'ar'#237'eis';
        a_6[85].Index := 84;
        a_6[85].Result := 1;
        a_6[85].Method := nil;

        a_6[86].Str  := 'er'#237'eis';
        a_6[86].Index := 84;
        a_6[86].Result := 1;
        a_6[86].Method := nil;

        a_6[87].Str  := 'ir'#237'eis';
        a_6[87].Index := 84;
        a_6[87].Result := 1;
        a_6[87].Method := nil;

        a_6[88].Str  := 'ados';
        a_6[88].Index := -1;
        a_6[88].Result := 1;
        a_6[88].Method := nil;

        a_6[89].Str  := 'idos';
        a_6[89].Index := -1;
        a_6[89].Result := 1;
        a_6[89].Method := nil;

        a_6[90].Str  := 'amos';
        a_6[90].Index := -1;
        a_6[90].Result := 1;
        a_6[90].Method := nil;

        a_6[91].Str  := #225'ramos';
        a_6[91].Index := 90;
        a_6[91].Result := 1;
        a_6[91].Method := nil;

        a_6[92].Str  := #233'ramos';
        a_6[92].Index := 90;
        a_6[92].Result := 1;
        a_6[92].Method := nil;

        a_6[93].Str  := #237'ramos';
        a_6[93].Index := 90;
        a_6[93].Result := 1;
        a_6[93].Method := nil;

        a_6[94].Str  := #225'vamos';
        a_6[94].Index := 90;
        a_6[94].Result := 1;
        a_6[94].Method := nil;

        a_6[95].Str  := #237'amos';
        a_6[95].Index := 90;
        a_6[95].Result := 1;
        a_6[95].Method := nil;

        a_6[96].Str  := 'ar'#237'amos';
        a_6[96].Index := 95;
        a_6[96].Result := 1;
        a_6[96].Method := nil;

        a_6[97].Str  := 'er'#237'amos';
        a_6[97].Index := 95;
        a_6[97].Result := 1;
        a_6[97].Method := nil;

        a_6[98].Str  := 'ir'#237'amos';
        a_6[98].Index := 95;
        a_6[98].Result := 1;
        a_6[98].Method := nil;

        a_6[99].Str  := 'emos';
        a_6[99].Index := -1;
        a_6[99].Result := 1;
        a_6[99].Method := nil;

        a_6[100].Str  := 'aremos';
        a_6[100].Index := 99;
        a_6[100].Result := 1;
        a_6[100].Method := nil;

        a_6[101].Str  := 'eremos';
        a_6[101].Index := 99;
        a_6[101].Result := 1;
        a_6[101].Method := nil;

        a_6[102].Str  := 'iremos';
        a_6[102].Index := 99;
        a_6[102].Result := 1;
        a_6[102].Method := nil;

        a_6[103].Str  := #225'ssemos';
        a_6[103].Index := 99;
        a_6[103].Result := 1;
        a_6[103].Method := nil;

        a_6[104].Str  := #234'ssemos';
        a_6[104].Index := 99;
        a_6[104].Result := 1;
        a_6[104].Method := nil;

        a_6[105].Str  := #237'ssemos';
        a_6[105].Index := 99;
        a_6[105].Result := 1;
        a_6[105].Method := nil;

        a_6[106].Str  := 'imos';
        a_6[106].Index := -1;
        a_6[106].Result := 1;
        a_6[106].Method := nil;

        a_6[107].Str  := 'armos';
        a_6[107].Index := -1;
        a_6[107].Result := 1;
        a_6[107].Method := nil;

        a_6[108].Str  := 'ermos';
        a_6[108].Index := -1;
        a_6[108].Result := 1;
        a_6[108].Method := nil;

        a_6[109].Str  := 'irmos';
        a_6[109].Index := -1;
        a_6[109].Result := 1;
        a_6[109].Method := nil;

        a_6[110].Str  := #225'mos';
        a_6[110].Index := -1;
        a_6[110].Result := 1;
        a_6[110].Method := nil;

        a_6[111].Str  := 'ar'#225's';
        a_6[111].Index := -1;
        a_6[111].Result := 1;
        a_6[111].Method := nil;

        a_6[112].Str  := 'er'#225's';
        a_6[112].Index := -1;
        a_6[112].Result := 1;
        a_6[112].Method := nil;

        a_6[113].Str  := 'ir'#225's';
        a_6[113].Index := -1;
        a_6[113].Result := 1;
        a_6[113].Method := nil;

        a_6[114].Str  := 'eu';
        a_6[114].Index := -1;
        a_6[114].Result := 1;
        a_6[114].Method := nil;

        a_6[115].Str  := 'iu';
        a_6[115].Index := -1;
        a_6[115].Result := 1;
        a_6[115].Method := nil;

        a_6[116].Str  := 'ou';
        a_6[116].Index := -1;
        a_6[116].Result := 1;
        a_6[116].Method := nil;

        a_6[117].Str  := 'ar'#225;
        a_6[117].Index := -1;
        a_6[117].Result := 1;
        a_6[117].Method := nil;

        a_6[118].Str  := 'er'#225;
        a_6[118].Index := -1;
        a_6[118].Result := 1;
        a_6[118].Method := nil;

        a_6[119].Str  := 'ir'#225;
        a_6[119].Index := -1;
        a_6[119].Result := 1;
        a_6[119].Method := nil;

    SetLength(a_7, 7);
        a_7[0].Str  := 'a';
        a_7[0].Index := -1;
        a_7[0].Result := 1;
        a_7[0].Method := nil;

        a_7[1].Str  := 'i';
        a_7[1].Index := -1;
        a_7[1].Result := 1;
        a_7[1].Method := nil;

        a_7[2].Str  := 'o';
        a_7[2].Index := -1;
        a_7[2].Result := 1;
        a_7[2].Method := nil;

        a_7[3].Str  := 'os';
        a_7[3].Index := -1;
        a_7[3].Result := 1;
        a_7[3].Method := nil;

        a_7[4].Str  := #225;
        a_7[4].Index := -1;
        a_7[4].Result := 1;
        a_7[4].Method := nil;

        a_7[5].Str  := #237;
        a_7[5].Index := -1;
        a_7[5].Result := 1;
        a_7[5].Method := nil;

        a_7[6].Str  := #243;
        a_7[6].Index := -1;
        a_7[6].Result := 1;
        a_7[6].Method := nil;

    SetLength(a_8, 4);
        a_8[0].Str  := 'e';
        a_8[0].Index := -1;
        a_8[0].Result := 1;
        a_8[0].Method := nil;

        a_8[1].Str  := #231;
        a_8[1].Index := -1;
        a_8[1].Result := 2;
        a_8[1].Method := nil;

        a_8[2].Str  := #233;
        a_8[2].Index := -1;
        a_8[2].Result := 1;
        a_8[2].Method := nil;

        a_8[3].Str  := #234;
        a_8[3].Index := -1;
        a_8[3].Result := 1;
        a_8[3].Method := nil;

End;

Function TPortugueseStemmer.stem : Boolean;
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
    lab21;
Begin
    v_1 := FCursor;
lab1:
    Begin
        v_2 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_0, 3);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom('a~');
            End;
            2:
            Begin
                SliceFrom('o~');
            End;
            3:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab2;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab1;
lab2:
        FCursor := v_2;
    End;
lab0:
    FCursor := v_1;
    I_pV := FLimit;
    I_p1 := FLimit;
    I_p2 := FLimit;
    v_3 := FCursor;
    Repeat
        v_4 := FCursor;
        If (Not (InGrouping(g_v, 97, 250))) Then
        Begin
            goto lab5;
        End;
        Repeat
            v_5 := FCursor;
            If (Not (OutGrouping(g_v, 97, 250))) Then
            Begin
                goto lab6;
            End;
            If (Not (GoOutGrouping(g_v, 97, 250))) Then
            Begin
                goto lab6;
            End;
            Inc(FCursor);
            Break;
lab6:
            FCursor := v_5;
            If (Not (InGrouping(g_v, 97, 250))) Then
            Begin
                goto lab5;
            End;
            If (Not (GoInGrouping(g_v, 97, 250))) Then
            Begin
                goto lab5;
            End;
            Inc(FCursor);
        Until True;
        Break;
lab5:
        FCursor := v_4;
        If (Not (OutGrouping(g_v, 97, 250))) Then
        Begin
            goto lab4;
        End;
        Repeat
            v_6 := FCursor;
            If (Not (OutGrouping(g_v, 97, 250))) Then
            Begin
                goto lab7;
            End;
            If (Not (GoOutGrouping(g_v, 97, 250))) Then
            Begin
                goto lab7;
            End;
            Inc(FCursor);
            Break;
lab7:
            FCursor := v_6;
            If (Not (InGrouping(g_v, 97, 250))) Then
            Begin
                goto lab4;
            End;
            If (FCursor >= FLimit) Then
            Begin
                goto lab4;
            End;
            Inc(FCursor);
        Until True;
    Until True;
    I_pV := FCursor;
lab4:
    FCursor := v_3;
    v_7 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 250))) Then
    Begin
        goto lab8;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 250))) Then
    Begin
        goto lab8;
    End;
    Inc(FCursor);
    I_p1 := FCursor;
    If (Not (GoOutGrouping(g_v, 97, 250))) Then
    Begin
        goto lab8;
    End;
    Inc(FCursor);
    If (Not (GoInGrouping(g_v, 97, 250))) Then
    Begin
        goto lab8;
    End;
    Inc(FCursor);
    I_p2 := FCursor;
lab8:
    FCursor := v_7;
lab3:
    FBkLimit := FCursor; FCursor := FLimit;
    v_8 := FLimit - FCursor;
    Repeat
        v_9 := FLimit - FCursor;
        v_10 := FLimit - FCursor;
        Repeat
            v_11 := FLimit - FCursor;
            FKet := FCursor;
            AmongVar := FindAmongBk(a_5, 45);
            If (AmongVar = 0) Then
            Begin
                goto lab11;
            End;
            FBra := FCursor;
            Case AmongVar Of
                1:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceDel;
                End;
                2:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceFrom('log');
                End;
                3:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceFrom('u');
                End;
                4:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceFrom('ente');
                End;
                5:
                Begin
                    If I_p1 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceDel;
                    v_12 := FLimit - FCursor;
                    FKet := FCursor;
                    AmongVar := FindAmongBk(a_2, 4);
                    If (AmongVar = 0) Then
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
                    Case AmongVar Of
                        1:
                        Begin
                            FKet := FCursor;
                            If (Not (EqSBk('at'))) Then
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
                        End;
                    End;
lab12:
                End;
                6:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceDel;
                    v_13 := FLimit - FCursor;
                    FKet := FCursor;
                    If (FindAmongBk(a_3, 3) = 0) Then
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
                7:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceDel;
                    v_14 := FLimit - FCursor;
                    FKet := FCursor;
                    If (FindAmongBk(a_4, 3) = 0) Then
                    Begin
                        FCursor := FLimit - v_14;
                        goto lab14;
                    End;
                    FBra := FCursor;
                    If I_p2 > FCursor Then
                    Begin
                        FCursor := FLimit - v_14;
                        goto lab14;
                    End;
                    SliceDel;
lab14:
                End;
                8:
                Begin
                    If I_p2 > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    SliceDel;
                    v_15 := FLimit - FCursor;
                    FKet := FCursor;
                    If (Not (EqSBk('at'))) Then
                    Begin
                        FCursor := FLimit - v_15;
                        goto lab15;
                    End;
                    FBra := FCursor;
                    If I_p2 > FCursor Then
                    Begin
                        FCursor := FLimit - v_15;
                        goto lab15;
                    End;
                    SliceDel;
lab15:
                End;
                9:
                Begin
                    If I_pV > FCursor Then
                    Begin
                        goto lab11;
                    End;
                    If (Not (EqSBk('e'))) Then
                    Begin
                        goto lab11;
                    End;
                    SliceFrom('ir');
                End;
            End;
            Break;
lab11:
            FCursor := FLimit - v_11;
            If (FCursor < I_pV) Then
            Begin
                goto lab10;
            End;
            v_16 := FBkLimit;
            FBkLimit := I_pV;
            FKet := FCursor;
            If (FindAmongBk(a_6, 120) = 0) Then
            Begin
                FBkLimit := v_16;
                goto lab10;
            End;
            FBra := FCursor;
            SliceDel;
            FBkLimit := v_16;
        Until True;
        FCursor := FLimit - v_10;
        v_17 := FLimit - FCursor;
        FKet := FCursor;
        If (Not (EqSBk('i'))) Then
        Begin
            goto lab16;
        End;
        FBra := FCursor;
        v_18 := FLimit - FCursor;
        If (Not (EqSBk('c'))) Then
        Begin
            goto lab16;
        End;
        FCursor := FLimit - v_18;
        If I_pV > FCursor Then
        Begin
            goto lab16;
        End;
        SliceDel;
lab16:
        FCursor := FLimit - v_17;
        Break;
lab10:
        FCursor := FLimit - v_9;
        FKet := FCursor;
        If (FindAmongBk(a_7, 7) = 0) Then
        Begin
            goto lab9;
        End;
        FBra := FCursor;
        If I_pV > FCursor Then
        Begin
            goto lab9;
        End;
        SliceDel;
    Until True;
lab9:
    FCursor := FLimit - v_8;
    v_19 := FLimit - FCursor;
    FKet := FCursor;
    AmongVar := FindAmongBk(a_8, 4);
    If (AmongVar = 0) Then
    Begin
        goto lab17;
    End;
    FBra := FCursor;
    Case AmongVar Of
        1:
        Begin
            If I_pV > FCursor Then
            Begin
                goto lab17;
            End;
            SliceDel;
            FKet := FCursor;
            Repeat
                v_20 := FLimit - FCursor;
                If (Not (EqSBk('u'))) Then
                Begin
                    goto lab18;
                End;
                FBra := FCursor;
                v_21 := FLimit - FCursor;
                If (Not (EqSBk('g'))) Then
                Begin
                    goto lab18;
                End;
                FCursor := FLimit - v_21;
                Break;
lab18:
                FCursor := FLimit - v_20;
                If (Not (EqSBk('i'))) Then
                Begin
                    goto lab17;
                End;
                FBra := FCursor;
                v_22 := FLimit - FCursor;
                If (Not (EqSBk('c'))) Then
                Begin
                    goto lab17;
                End;
                FCursor := FLimit - v_22;
            Until True;
            If I_pV > FCursor Then
            Begin
                goto lab17;
            End;
            SliceDel;
        End;
        2:
        Begin
            SliceFrom('c');
        End;
    End;
lab17:
    FCursor := FLimit - v_19;
    FCursor := FBkLimit;
    v_23 := FCursor;
lab20:
    Begin
        v_24 := FCursor;
        FBra := FCursor;
        AmongVar := FindAmong(a_1, 3);
        FKet := FCursor;
        Case AmongVar Of
            1:
            Begin
                SliceFrom(#227);
            End;
            2:
            Begin
                SliceFrom(#245);
            End;
            3:
            Begin
                If (FCursor >= FLimit) Then
                Begin
                    goto lab21;
                End;
                Inc(FCursor);
            End;
        End;
        goto lab20;
lab21:
        FCursor := v_24;
    End;
lab19:
    FCursor := v_23;
    Result := True;
End;

End.
