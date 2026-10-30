/// First and last names by region, romanised, for the story's fictional
/// people. A person's full name is one first name with one last name from
/// the same pool, so it describes nobody in particular.
final namePools = <String, ({List<String> first, List<String> last})>{
  'de': _pool(
    'Anna, Lukas, Katrin, Felix, Sabine, Jonas, Miriam, Tobias, Lena, Florian, '
        'Carina, Matthias, Johanna, Stefan, Theresa, Benedikt, Ines, Moritz, '
        'Verena, Dominik, Franziska, Kilian, Nadine, Severin, Ute',
    'Reinholt, Brandstätter, Kessler, Vogtmann, Lechner, Eberhardt, '
        'Wimmer, Seidlitz, Hollerer, Ganghofer, Bichlmaier, Strasser, Kolb, '
        'Achleitner, Haberl, Pfister, Rauscher, Lindner, Obermaier, Zehetner, '
        'Kranzler, Mittermeier, Dorfner, Heiligensetzer, Aigner',
  ),
  'en': _pool(
    'Hannah, Oliver, Grace, Callum, Imogen, Rhys, Eleanor, Finn, Maisie, '
        'Declan, Harriet, Owen, Bethany, Ewan, Rosalind, Tristan, Molly, '
        'Hamish, Clara, Jasper, Freya, Rowan, Lydia, Angus, Tamsin',
    'Brookfield, Ashdown, Pennington, Hartwell, Fairbairn, Calloway, '
        'Whitcombe, Larkspur, Ellery, Thorne, Mercer, Halloran, Prewitt, '
        'Langford, Castleton, Dunmore, Rookwood, Wetherby, Kingsley, Fenwick, '
        'Holloway, Ainsworth, Blackmore, Penrose, Garside',
  ),
  'ar': _pool(
    'Ahmed, Mona, Karim, Yasmin, Omar, Laila, Tarek, Nour, Hany, Salma, '
        'Mostafa, Dina, Sherif, Rania, Amr, Heba, Walid, Mariam, Khaled, '
        'Aya, Hossam, Nadia, Ramy, Farida, Yehia',
    'El-Masry, Abdelaziz, Hassanein, Fathy, Soliman, El-Gendy, Mahfouz, '
        'Ragab, Shalaby, Zaki, El-Sayed, Badawi, Hegazy, Morsy, Nassar, '
        'Abdelrahman, Fouad, Ghoneim, Kamel, Lotfy, Mansour, Sabry, Tawfik, '
        'Youssef, Hamdy',
  ),
  'id': _pool(
    'Ayu, Made, Wayan, Putu, Ketut, Dewi, Agus, Sari, Budi, Ratna, Komang, '
        'Indah, Rizal, Fitri, Hendra, Wulan, Yusuf, Lestari, Arief, Intan, '
        'Bayu, Ningsih, Dimas, Maya, Teguh',
    'Setiawati, Wirawan, Pratama, Santoso, Kusuma, Hidayat, Saputra, '
        'Wibowo, Gunawan, Purnama, Suryadi, Hartono, Nugroho, Permana, '
        'Rahmawati, Susanto, Utomo, Wijaya, Yulianto, Kurniawan, Mahendra, '
        'Sudarsono, Tanjung, Halim, Lubis',
  ),
  'th': _pool(
    'Somchai, Malee, Anong, Kittisak, Ploy, Nattapong, Siriporn, Wichai, '
        'Kanya, Thanawat, Pimchanok, Sakda, Jintana, Prasert, Arunee, '
        'Chaiwat, Duangjai, Ekkachai, Nittaya, Pongsak, Ratana, Surasak, '
        'Thida, Weerapong, Yupa',
    'Srisuk, Chaiyaporn, Wongsawat, Kittikhun, Boonmee, Rattanakorn, '
        'Phromma, Sangthong, Thongdee, Jaidee, Suwannarat, Khamphan, '
        'Intharak, Saengchai, Pholsri, Meesuk, Rungrot, Bunnag, Kaewkla, '
        'Nakprasert, Sirikul, Thammasak, Wannasiri, Yodmanee, Charoenkit',
  ),
  'fil': _pool(
    'Marisol, Jomar, Liza, Rodel, Analyn, Jericho, Maricel, Dindo, Kristine, '
        'Arnel, Joy, Ramil, Shiela, Noel, Grace, Edgardo, Rowena, Jun, '
        'Marites, Bong, Cherry, Rommel, Divina, Alvin, Tess',
    'Dela Cruz, Bautista, Villanueva, Ocampo, Mendoza, Aquino, Pascual, '
        'Manalo, Soriano, Gatchalian, Navarro, Salazar, Dimaculangan, '
        'Macaraeg, Tolentino, Lacson, Cabrera, Fajardo, Ilagan, Javier, '
        'Lozada, Magbanua, Pangilinan, Quijano, Umali',
  ),
  'dv': _pool(
    'Ahmed, Aishath, Ibrahim, Mariyam, Hussain, Fathimath, Ali, Aminath, '
        'Mohamed, Hawwa, Hassan, Shifa, Ismail, Zeenath, Abdulla, Nashwa, '
        'Moosa, Raufa, Ahusan, Lamha, Shiham, Nazeera, Riyaz, Thasleema, '
        'Yoosuf',
    'Rasheed, Naseem, Shareef, Waheed, Manik, Didi, Fulhu, Saeed, Zahir, '
        'Latheef, Hameed, Riza, Nadheem, Faiz, Shakir, Athif, Zuhair, Hilmy, '
        'Ilham, Jameel, Kamil, Mausoom, Niyaz, Rameez, Sodiq',
  ),
  'ms': _pool(
    'Aiman, Nurul, Hafiz, Siti, Faizal, Aisyah, Zulkifli, Farah, Azlan, '
        'Liyana, Shahrul, Hidayah, Iskandar, Amira, Kamal, Syafiqah, Razak, '
        'Nadia, Hakim, Izzati, Firdaus, Atiqah, Rizwan, Balqis, Danial',
    'Rahman, Ismail, Hashim, Yusof, Osman, Abdullah, Latif, Salleh, Mokhtar, '
        'Hamzah, Jaafar, Kassim, Mansor, Nordin, Ramli, Sulaiman, Talib, '
        'Wahab, Zainal, Bakar, Daud, Ghazali, Harun, Ishak, Mustafa',
  ),
  'ja': _pool(
    'Kenji, Yuki, Haruto, Aoi, Sota, Hina, Ren, Sakura, Daiki, Mei, Takumi, '
        'Yui, Kaito, Rina, Shota, Emi, Yuto, Miyu, Ryota, Nanami, Kohei, '
        'Ayaka, Hiroshi, Mao, Tsubasa',
    'Moriwaki, Takenaka, Hoshino, Kanemoto, Uchida, Shimabukuro, Higa, '
        'Nakandakari, Teruya, Kinjo, Oshiro, Yonamine, Arakaki, Chinen, '
        'Fukuhara, Ishimine, Kayo, Miyagi, Nakasone, Tamashiro, Toguchi, '
        'Uehara, Yamashiro, Zukeran, Gushiken',
  ),
  'pacific': _pool(
    'Kiomy, Tevita, Leilani, Makoa, Hinemoa, Sione, Lanakila, Teuila, '
        'Mosese, Kalani, Ioane, Malia, Keoni, Losana, Tavita, Noelani, '
        'Rangi, Mele, Kawika, Tiare, Ielu, Akanesi, Pita, Moana, Ruben',
    'Tellei, Ngiraked, Kabua, Langrine, Etpison, Ngirmang, Rengulbai, '
        'Debrum, Zackhras, Lomae, Kilma, Anjain, Heine, Riklon, Ishoda, '
        'Mendiola, Sablan, Taitano, Aguon, Camacho, Salas, Tenorio, Borja, '
        'Pangelinan, Quitugua',
  ),
  'es': _pool(
    'Diego, Lucía, Mateo, Valentina, Andrés, Camila, Santiago, Isabela, '
        'Julián, Mariana, Sebastián, Daniela, Tomás, Paula, Emilio, Gabriela, '
        'Rodrigo, Ximena, Nicolás, Catalina, Felipe, Renata, Joaquín, Elena, '
        'Ignacio',
    'Albarrán, Quintero, Echeverría, Saldaña, Villalobos, Cifuentes, Arriaga, '
        'Benavides, Carvajal, Duarte, Escobedo, Fajardo, Galindo, Hurtado, '
        'Iturbe, Jaramillo, Larrea, Montalvo, Navarrete, Olivares, Pacheco, '
        'Riquelme, Sepúlveda, Toledo, Urrutia',
  ),
  'fr': _pool(
    'Camille, Julien, Manon, Thibault, Élodie, Romain, Chloé, Bastien, '
        'Aurélie, Maxime, Pauline, Quentin, Margaux, Florent, Léa, Gaëtan, '
        'Justine, Arnaud, Clémence, Yannick, Solène, Mathieu, Anaïs, Rémi, '
        'Océane',
    'Lefebvre, Marchand, Garnier, Rousseau, Fournier, Chevalier, Lambert, '
        'Girard, Bonnet, Dupuis, Mercier, Blanchard, Gauthier, Perrin, '
        'Moulin, Leclerc, Barbier, Renaud, Collin, Vidal, Arnaud, Picard, '
        'Roussel, Brun, Fontaine',
  ),
  'it': _pool(
    'Lena, Marco, Giulia, Alessandro, Chiara, Matteo, Francesca, Lorenzo, '
        'Sara, Davide, Elisa, Riccardo, Martina, Simone, Federica, Andrea, '
        'Valeria, Nicola, Silvia, Stefano, Ilaria, Fabio, Serena, Paolo, '
        'Beatrice',
    'Marchetti, Bernasconi, Rusconi, Galli, Pedrazzini, Ferrari, Colombo, '
        'Bianchi, Fontana, Cattaneo, Gianella, Moretti, Rossetti, Brenni, '
        'Lurati, Pellandini, Zanetti, Cereghetti, Bassi, Caccia, Delmenico, '
        'Ghirlanda, Mottis, Rezzonico, Sartori',
  ),
  'hr': _pool(
    'Ivana, Luka, Petra, Marko, Ana, Ivan, Maja, Josip, Katarina, Tomislav, '
        'Lucija, Mateo, Nina, Filip, Ema, Dario, Mia, Ante, Sara, Domagoj, '
        'Tena, Krešimir, Iva, Hrvoje, Lana',
    'Kovačević, Horvat, Babić, Marić, Jurić, Novak, Knežević, Vuković, '
        'Pavlović, Blažević, Grgić, Matić, Perić, Radić, Šarić, Tomić, '
        'Vidović, Zorić, Lovrić, Bašić, Čulić, Dujmović, Fabijanić, '
        'Gašparović, Hrvatin',
  ),
  'mt': _pool(
    'Matthew, Maria, Luke, Rebecca, Jean, Nicole, Kurt, Martina, Clayton, '
        'Rachel, Karl, Francesca, Neil, Daniela, Ryan, Christine, Andre, '
        'Stephanie, Glen, Roberta, Mark, Diane, Josef, Sarah, Elton',
    'Borg, Camilleri, Vella, Farrugia, Zammit, Galea, Micallef, Grech, '
        'Attard, Spiteri, Azzopardi, Cassar, Mifsud, Caruana, Debono, Xuereb, '
        'Fenech, Muscat, Sammut, Agius, Bonnici, Abela, Schembri, Pace, '
        'Mangion',
  ),
  'el': _pool(
    'Andreas, Eleni, Christos, Maria, Giorgos, Anna, Nikos, Sofia, Panagiotis, '
        'Despina, Kostas, Ioanna, Michalis, Katerina, Stavros, Georgia, '
        'Antonis, Christina, Marios, Elena, Loizos, Androulla, Stelios, Maro, '
        'Demetris',
    'Christodoulou, Georgiou, Ioannou, Charalambous, Constantinou, '
        'Panayiotou, Kyriacou, Michael, Demetriou, Nicolaou, Antoniou, '
        'Hadjipavlou, Theodorou, Savva, Loizou, Stylianou, Efthymiou, '
        'Christofi, Neophytou, Pavlou, Kleanthous, Zachariou, Andreou, '
        'Petrou, Mavrou',
  ),
  'no': _pool(
    'Ingrid, Sindre, Marte, Eirik, Silje, Håkon, Ragnhild, Torbjørn, Kari, '
        'Øyvind, Hilde, Anders, Solveig, Magnus, Liv, Sigurd, Tone, Vegard, '
        'Astrid, Even, Guro, Kjetil, Maren, Leif, Synnøve',
    'Haugland, Solheim, Bakke, Lunde, Fjeldstad, Myklebust, Tveit, '
        'Ødegård, Rønning, Sandvik, Aasland, Birkeland, Eikeland, Grøtte, '
        'Holm, Kvamme, Løvås, Nygård, Opsahl, Strand, Tjelta, Vik, Aune, '
        'Brekke, Dahle',
  ),
  'nl': _pool(
    'Sanne, Daan, Femke, Jeroen, Lotte, Bram, Ilse, Thijs, Marloes, Ruben, '
        'Eline, Joost, Anouk, Sjoerd, Wendy, Niels, Esther, Gijs, Manon, '
        'Rutger, Shirley, Glenn, Chanella, Ruthsel, Jurgen',
    'Martina, Statia, Bernabela, Doran, Fecunda, Isenia, Kroon, Leito, '
        'Maduro, Navarro, Ostiana, Pieternella, Rosaria, Sint Jago, Trappenberg, '
        'Vlijt, Wawoe, Zimmerman, de Windt, Hooi, Juliana, Lourens, Martis, '
        'Rojer, Schoop',
  ),
};

({List<String> first, List<String> last}) _pool(String first, String last) =>
    (first: first.split(', '), last: last.split(', '));
