# Backup

`backup` is a simple daemon that backs up server assest to [Amazon Glacier](https://aws.amazon.com/glacier/). Due to the nature of Amazon Glacier, it must run continuously as a daemon to work with the service's long async behavior.

## Installation

Although the project is structured as a Ruby gem, it is not intended to be released as one. Simply checkout the code, create a `config.yml` file from the `config.yml.example` file, and run it.

## Configuration

The following options are available for the `config.yml` file:

`aws_access_key_id`: The AWS access key ID.

`aws_secret_access_key`: The AWS secret access key.

`glacier_arn`: The Amazon Resource Name to store your backups in.

`glacier_vault`: The existing Amazon Glacier Vault to store your backups in.

`backup_directories`: A list of directories that should be backed up. Each entry requires a `name` and `path`.

`backup_interval`: The interval in hours to back up each directory.

`purge_age`: The age in hours before an archive is deleted.

`purge_interval`: The interval in hours to start a purge discovery process.

## Usage

After you have created your `config.yml` file, simply run the following from the root of the project:

    # bundle exec ./exe/backup -c /path/to/your/config.yml

The above command will run forever, performing backups and purges as configured. The scheduled tasks do not fire immediately. If you would also like to perform these tasks immediately on launch, add the `-f` option.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stack/backup.
