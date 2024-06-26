# Generated by Django 4.2.11 on 2024-06-20 08:02

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('mathesar', '0007_users_permissions_remodel'),
    ]

    operations = [
        migrations.CreateModel(
            name='ColumnMetaData',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('table_oid', models.PositiveIntegerField()),
                ('attnum', models.PositiveIntegerField()),
                ('bool_input', models.CharField(blank=True, choices=[('dropdown', 'dropdown'), ('checkbox', 'checkbox')])),
                ('bool_true', models.CharField(default='True')),
                ('bool_false', models.CharField(default='False')),
                ('num_min_frac_digits', models.PositiveIntegerField(blank=True)),
                ('num_max_frac_digits', models.PositiveIntegerField(blank=True)),
                ('num_show_as_perc', models.BooleanField(default=False)),
                ('mon_currency_symbol', models.CharField(default='$')),
                ('mon_currency_location', models.CharField(choices=[('after-minus', 'after-minus'), ('end-with-space', 'end-with-space')], default='after-minus')),
                ('time_format', models.CharField(blank=True)),
                ('date_format', models.CharField(blank=True)),
                ('duration_min', models.CharField(blank=True, max_length=255)),
                ('duration_max', models.CharField(blank=True, max_length=255)),
                ('duration_show_units', models.BooleanField(default=True)),
                ('database', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='mathesar.database')),
            ],
        ),
        migrations.AddConstraint(
            model_name='columnmetadata',
            constraint=models.UniqueConstraint(fields=('database', 'table_oid', 'attnum'), name='unique_column_metadata'),
        ),
        migrations.AddConstraint(
            model_name='columnmetadata',
            constraint=models.CheckConstraint(check=models.Q(('num_max_frac_digits__lte', 20), ('num_min_frac_digits__lte', 20), ('num_min_frac_digits__lte', models.F('num_max_frac_digits'))), name='frac_digits_integrity'),
        ),
    ]
