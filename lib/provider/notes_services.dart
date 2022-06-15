import 'dart:convert';
import 'dart:io';

import 'package:dapp/modal/Note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

class NotesServices extends ChangeNotifier {
  List<Note> notes = [];
  final String _rpcUrl =
      Platform.isAndroid ? 'http://10.0.2.2:7545' : 'http://127.0.0.1:7545';
  final String _wsUrl =
      Platform.isAndroid ? 'http://10.0.2.2:7545' : 'ws://127.0.0.1:7545';
  final String _privateKey =
      "bc35d428d71ef864f711fe20d9aeb3b4cd6b4ca0cf88633d9c250091e526ae90";

  late Web3Client _web3client;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  set setIsLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  NotesServices() {
    init();
  }

  Future<void> init() async {
    try {
      _web3client = Web3Client(
        _rpcUrl,
        http.Client(),
        socketConnector: () {
          return IOWebSocketChannel.connect(_wsUrl).cast<String>();
        },
      );
      await getABI();
      await getCredentials();
      await getDeployedContract();
    } catch (e) {
      Logger().e(e);
    }
  }

  late ContractAbi _abiCode;
  late EthereumAddress _contractAddress;

  Future<void> getABI() async {
    try {
      String abiFile =
          await rootBundle.loadString('build/contracts/NotesContract.json');
      var jsonABI = jsonDecode(abiFile);
      _abiCode =
          ContractAbi.fromJson(jsonEncode(jsonABI['abi']), "NotesContract");
      _contractAddress =
          EthereumAddress.fromHex(jsonABI["networks"]["5777"]["address"]);
    } catch (e) {
      Logger().e(e);
    }
  }

  late EthPrivateKey _creds;

  Future<void> getCredentials() async {
    try {
      _creds = EthPrivateKey.fromHex(_privateKey);
    } catch (e) {
      Logger().e(e);
    }
  }

  late DeployedContract _deployedContract;
  late ContractFunction _createNote;
  late ContractFunction _deleteNote;
  late ContractFunction _notes;
  late ContractFunction _noteCount;

  Future<void> getDeployedContract() async {
    try {
      _deployedContract = DeployedContract(_abiCode, _contractAddress);
      _createNote = _deployedContract.function('createNote');
      _deleteNote = _deployedContract.function('deleteNote');
      _notes = _deployedContract.function('notes');
      _noteCount = _deployedContract.function('noteCount');
      await fetchNotes();
    } catch (e) {
      Logger().e(e);
    }
  }

  Future<void> fetchNotes() async {
    try {
      List totalTaskList = await _web3client
          .call(contract: _deployedContract, function: _noteCount, params: []);
      int totalTaskLen = totalTaskList[0].toInt();
      notes.clear();
      for (var i = 0; i < totalTaskLen; i++) {
        var temp = await _web3client.call(
            contract: _deployedContract,
            function: _notes,
            params: [BigInt.from(i)]);
        if (temp[1] != "") {
          notes.add(Note(
              id: (temp[0] as BigInt).toInt(),
              title: temp[1],
              description: temp[2]));
        }
      }
    } catch (e) {
      Logger().e(e);
    } finally {
      setIsLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(String title, String description) async {
    try {
      await _web3client.sendTransaction(
          _creds,
          Transaction.callContract(
              contract: _deployedContract,
              function: _createNote,
              parameters: [title, description]));
    } catch (e) {
      Logger().e(e);
    } finally {
      setIsLoading = true;
      notifyListeners();
      fetchNotes();
    }
  }

  Future<void> deleteNote(int id) async {
    try {
      await _web3client.sendTransaction(
          _creds,
          Transaction.callContract(
              contract: _deployedContract,
              function: _deleteNote,
              parameters: [BigInt.from(id)]));
    } catch (e) {
      Logger().e(e);
    } finally {
      setIsLoading = true;
      notifyListeners();
      fetchNotes();
    }
  }
}
