import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GridCard extends StatelessWidget{
  const GridCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Column(
        children: [
          Row(
            children: [
              Text("Title"),
              Expanded(child: SizedBox()),
              IconButton(onPressed: (){}, icon: Icon(Icons.arrow_forward_ios))
            ],
          ),
          GridView(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3),
            shrinkWrap: true,
            children: [
              Card(),
              Card(),
              Card()
            ],
          )
        ],
      ),
    );
  }

}