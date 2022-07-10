import 'dart:async';
import 'dart:math' show Random;
import 'package:serveme/serveme.dart';

/// This file is generated by packme/compile.dart using
/// packme/example-users.json manifest file.
import 'generated/example-users.generated.dart';

/// Some helper functions.

int randomInt() {
	final Random rand = Random();
	return rand.nextInt(255);
}

String randomString({int min = 3, int max = 9, bool spaces = false}) {
	final Random rand = Random();
	const String characters = ' qwertyuiopasdfghjklzcvbnm';
	String result = '';
	final int len = rand.nextInt(max - min) + min;
	final int from = spaces ? 0 : 1;
	const int to = characters.length - 1;
	for (int i = 0; i < len; i++) result += characters[rand.nextInt(to - from) + from];
	return result;
}

List<String>messageToStrings(GetResponse message) {
	final List<String> result = <String>[];
	result.add('email: ${message.email}');
	result.add('nickname: ${message.nickname}');
	result.add('hidden: ${message.hidden}');
	result.add('created: ${message.created}');
	result.add('firstName: ${message.info.firstName}');
	result.add('lastName: ${message.info.lastName}');
	result.add('age: ${message.info.age}');
	result.add('facebookId: ${message.social.facebookId}');
	result.add('twitterId: ${message.social.twitterId}');
	result.add('instagramId: ${message.social.instagramId}');
	result.add('posts: ${message.stats.posts}');
	result.add('comments: ${message.stats.comments}');
	result.add('likes: ${message.stats.likes}');
	result.add('dislikes: ${message.stats.dislikes}');
	result.add('rating: ${message.stats.rating}');
	return result;
}

/// Implementing our own config class since we want to add some custom fields
/// to our configuration and load some custom data from main config file.

class MehConfig extends Config {
	MehConfig(String filename) : super(filename) {
		/// At this point we can access to Map<String, dynamic> map field.
		aliveNotification = map['meh_messages']['alive_notification'] as String;
		spamMessage = map['meh_messages']['spam_message'] as String;
	}

	late String aliveNotification; /// Should be final but we will modify it.
	late final String spamMessage;
}

/// Implementing our own client class since we might want to add some custom
/// functionality such as user authorization etc.

class MehClient extends ServeMeClient {
	MehClient(ServeMeSocket socket) : super(socket) {
		userIsLocal = socket.httpRequest!.headers.host == '127.0.0.1';
	}

	late final bool userIsLocal;
	bool userEnteredPassword = false;
}

/// Implementing our main example module. Note that in order to make server run
/// this module it must be enabled in configuration file.

class MehModule extends Module<MehClient> {
	late Task _periodicShout;
	late Task _webSocketSpam;
	Future<void> Function(ConnectEvent<MehClient>)? onConnectListener;

	/// Since we're using custom Config class then we better override it a bit
	/// just to make sure it returns MehConfig, not default Config.

	@override
	MehConfig get config => super.config as MehConfig;

	/// Method init() will be called once after MongoDB initialized. Server will
	/// await each module init() completion.

	@override
	Future<void> init() async {
		/// Declare tasks for scheduler.
		_periodicShout = Task(DateTime.now(), (DateTime _) async {
			log(config.aliveNotification, CYAN);
		}, period: const Duration(seconds: 3));
		/// This task will spam all connected WebSocket clients.
		_webSocketSpam = Task(DateTime.now(), (DateTime _) async {
			/// We can pass PackMeMessage instance, Uint8List or String.
			server.broadcast(config.spamMessage);
		}, period: const Duration(seconds: 5));

		/// Once scheduled tasks will be processed until completed or discarded.
		scheduler.schedule(_periodicShout);
	}

	/// Method run() will be called once after all modules are initialized.
	/// Server will call run() method for all modules simultaneously.

	@override
	void run() {
		/// For the sake of example let's add some custom console commands.
		console.on('setMessage',
			(String line, __) {
				/// Don't. It is a bad practice to modify config like this :)
				config.aliveNotification = line;
				log('MehModule message is set to "$line"');
			},
			/// Using regular expression for command line format verification.
			validator: RegExp(r'^.*\S+.*$'), /// At least 1 printable character.
			/// Message to be used to show command help.
			usage: 'setMessage <message>',
			/// These commands will work the same way as setMessage.
			aliases: <String>['setMsg', 'setNotification'],
			/// These commands will not be executed but a hint will be given.
			similar: <String>['set', 'message'],
		);

		/// Now let's see how to use messages encoded with PackMe.
		/// It allows to use JSON manifest to describe data protocols and
		/// exchange any data between client and server.
		///
		/// See packme/compile.dart and example .json manifest files. We
		/// imported 'generated/example-users.generated.dart' which was created
		/// with compile.dart script.

		/// First we need to register our messages
		server.register(exampleUsersMessageFactory);

		/// Now let's add console command which will broadcast some message.
		console.on('sendPackedMessage', (_, __) {
			/// GetResponse is just the name of response message of command Get.
			/// It's declared in example-users.generated.dart.
			final GetResponse message = GetResponse(
				email: '${randomString()}@${randomString()}.com',
				nickname: 'Mr. ${randomString()}',
				hidden: false,
				created: DateTime.now(),
				info: GetResponseInfo(
					firstName: randomString(),
					lastName: randomString(),
					age: randomInt(),
				),
				social: GetResponseSocial(
					facebookId: randomInt() < 128 ? 'fbID_${randomString()}' : null,
					twitterId: randomInt() < 128 ? 'twID_${randomString()}' : null,
					instagramId: randomInt() < 128 ? 'inID_${randomString()}' : null,
				),
				stats: GetResponseStats(
					posts: randomInt(),
					comments: randomInt(),
					likes: randomInt() * 10,
					dislikes: randomInt(),
					rating: randomInt() / 25.5,
				),
				sessions: <GetResponseSession>[],
			);
			server.broadcast(message);
			log('Here is the message I sent:', MAGENTA);
			messageToStrings(message).forEach(log);
			log('Now waiting for echo response from client...', MAGENTA);
		});

		/// And finally we will start listening for messages from clients.
		events.listen<ConnectEvent<MehClient>>(onConnectListener = (ConnectEvent<MehClient> event) async {
			/// Listen to GetResponse message only.
			event.client.listen<GetResponse>((GetResponse data) async {
				log('Got response, decoded message:', MAGENTA);
				messageToStrings(data).forEach(log);
			});
			/// Listen to String data only
			event.client.listen<String>((String data) async {
				log('Got a string from client: "$data"', MAGENTA);
			});
		});

		log("MehModule is started. Apparently. Now let's spam them all.", MAGENTA);
		scheduler.schedule(_webSocketSpam);
	}

	/// Method dispose() will be called during server shutdown/restart process.
	/// Please do not forget to cancel your timers or subscriptions and release
	/// other resources in order to avoid memory leaks.

	@override
	Future<void> dispose() async {
		if (onConnectListener != null) events.cancel<ConnectEvent<MehClient>>(onConnectListener!);
		scheduler.discard(_periodicShout);
		scheduler.discard(_webSocketSpam);
	}
}

/// Note that server.run() method returns Future<bool> which might be handy in
/// some cases. It will return true if server initialization was successful and
/// false if initialization failed.

Future<void> main() async {
	final ServeMe<MehClient> server = ServeMe<MehClient>(
		/// Main configuration file extended with our own custom data.
		configFile: 'example/example.yaml',
		/// Tell server to use our own Config class.
		configFactory: (_) => MehConfig(_),
		/// Tell server to use our own Client class.
		clientFactory: (_) => MehClient(_),
		/// Pass our modules to server (don't forget to enable them in config).
		modules: <String, Module<MehClient>>{
			'meh': MehModule()
		},
	);

	final bool initializationResult = await server.run();
	print('Server initialization status: $initializationResult');
}