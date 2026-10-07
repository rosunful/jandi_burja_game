// import 'package:flutter/material.dart';

// void main() {
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(home: App());
//   }
// }

// class App extends StatefulWidget {
//   const App({super.key});

//   @override
//   State<App> createState() => _App();
// }

// class _App extends State<App> {
//   final List<String> keys = [
//     '0',
//     '/',
//     '*',
//     '-',
//     '7',
//     '8',
//     '9',
//     'c',
//     '4',
//     '5',
//     '6',
//     '+',
//     '1',
//     '2',
//     '3',
//     '=',
//   ];
//   String s = '';
//   String display = "";

//   void process(String value){
//     s = s +  value ;
//     display = s ;
     
//     setState(() {
      
//     });
//   }
 

//   void clean() {
//     s = "";
//     display = "";
//     setState(() {});
//   }

//   void total() {
//     if(s.contains('+')){
//     List <String> parts = s.split('+');

//     int result = 0 ;

//     for(String p in parts){
//       result = result + int.parse(p);
//     }

//     display = result.toString() ;
//     }else if(s.contains('-')){

//     ///this is for the subtraction 

//       List <String> sub = s.split('-');

//     int subres = int.parse(sub[0]) ;

//     for(int i = 1 ; i < sub.length ; i++ ){
//       subres = subres - int.parse(sub[i]);
//     }

//     display = subres.toString() ;
//     }
//     // display = " total $s ";
//     setState(() {});
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Column(
//           children: [
//             Text(display),
//             const SizedBox(height: 10),
//             GridView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: keys.length,
//               gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 4,
//                 crossAxisSpacing: 0,
//                 mainAxisSpacing: 0,
//                 childAspectRatio: 10.6,
//                 mainAxisExtent: 20,
//               ),
//               itemBuilder: (context, index) {
//                 final String label = keys[index];
//                 return InkWell(
//                   onTap: () {
//                     if (label == "c") {
//                       clean();
//                     } else if (label == "=") {
//                       total();
//                     } else {
//                       process(label);
//                     }
//                   },
//                   child: Text(label),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
