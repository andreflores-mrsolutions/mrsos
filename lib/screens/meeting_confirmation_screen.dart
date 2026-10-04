import 'package:flutter/material.dart';

class MeetingConfirmationScreen extends StatefulWidget {
  const MeetingConfirmationScreen({super.key, required this.proposal});
  final Map proposal;
  @override
  State<MeetingConfirmationScreen> createState() =>
      _MeetingConfirmationScreenState();
}

class _MeetingConfirmationScreenState extends State<MeetingConfirmationScreen> {
  late final _platform = TextEditingController(
    text: '${widget.proposal['mpPlataforma'] ?? ''}',
  );
  late final _link = TextEditingController(
    text: '${widget.proposal['mpLink'] ?? ''}',
  );
  String _delivery = 'link';
  String? _error;
  @override
  void dispose() {
    _platform.dispose();
    _link.dispose();
    super.dispose();
  }

  void _confirm() {
    final uri = Uri.tryParse(_link.text.trim());
    if (_platform.text.trim().isEmpty ||
        _platform.text.trim().length > 80 ||
        (_delivery == 'link' &&
            (uri == null ||
                uri.scheme != 'https' ||
                uri.host.isEmpty ||
                uri.userInfo.isNotEmpty))) {
      setState(
        () =>
            _error =
                'Indica la plataforma y un enlace HTTPS válido, o el envío por correo.',
      );
      return;
    }
    Navigator.pop(context, {
      'platform': _platform.text.trim(),
      'link': _link.text.trim(),
      'delivery': _delivery,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirmar reunión')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: _platform,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Plataforma (Meet, Teams, Zoom…)',
          ),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: _delivery,
          items: const [
            DropdownMenuItem(
              value: 'link',
              child: Text('Compartir enlace HTTPS'),
            ),
            DropdownMenuItem(
              value: 'email',
              child: Text('Enviar invitación por correo'),
            ),
          ],
          onChanged: (v) => setState(() => _delivery = v ?? 'link'),
        ),
        if (_delivery == 'link')
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Enlace de reunión'),
          )
        else
          const Text(
            'Después de confirmar deberás enviar la invitación con el enlace a los destinatarios indicados. Abrir el correo sólo prepara un borrador; no envía la invitación.',
          ),
        if (_error != null) Text(_error!),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Confirmar horario'),
        ),
      ],
    ),
  );
}
