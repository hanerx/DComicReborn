import 'package:dcomic/utils/image_utils.dart';
import 'package:dcomic/view/components/dcomic_image.dart';
import 'package:flutter/material.dart';

class CarouselItem extends StatelessWidget {
  final String title;
  final ImageEntity cover;
  final void Function(BuildContext context)? onTap;

  const CarouselItem({super.key, required this.title, required this.cover, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap==null?null:(){onTap!(context);},
      child: Container(
        margin: const EdgeInsets.all(5.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(5.0)),
          child: Stack(
            children: <Widget>[
              Center(
                child: DComicImage(
                  cover,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
              Positioned(
                bottom: 0.0,
                left: 0.0,
                right: 0.0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(200, 0, 0, 0),
                        Color.fromARGB(0, 0, 0, 0),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 0),
      child: InkWell(
        onTap: onTap==null?null:(){onTap!(context);},
        child: Center(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: DComicImage(
                  cover,
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: Color.fromARGB(
                        200,
                        Theme.of(context).colorScheme.primary.red,
                        Theme.of(context).colorScheme.primary.green,
                        Theme.of(context).colorScheme.primary.blue),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(
                        title,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
  }
}
