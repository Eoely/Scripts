#!/usr/bin/env python3

import json
import subprocess
import click
from colorama import init, Style, Fore

init()

# TODO: Rename User story? So it accepts as prompt without being wrapped in quotes
# TODO: Able to run it from any directory
# TODO: Set Iteration?
# TODO: Would be cool if I could link to parent items here aswell
# TODO: Better multi-line editor for description?
# TODO: "Compile" it so it can be ran as a command
valid_types = ["Epic", "Feature", "User Story",
               "Task",  "Bug", "Chore", "Discover"]

area_path = "SmartDok\Development\Pulse"
organization = "https://dev.azure.com/VismaSmartDok"
project = "SmartDok"
assigned_to = "Eivind Østlyngen"


@click.command()
@click.argument("type", type=click.Choice(valid_types, case_sensitive=False), required=False)
@click.option("--title", required=False)
@click.option("--description", required=False)
@click.option("--open", is_flag=True)
def main(type, title, description, open):
    if type is None:
        type = click.prompt(
            "Choose color",
            type=click.Choice(valid_types, case_sensitive=False)
        )

    if title is None:
        title = click.prompt("Title")

    if description is None:
        description = click.prompt(
            "Description", default="", show_default=False)

    command = (
        "az boards work-item create "
        f'--title "{title}" '
        f'--type "{type}" '
        f'--assigned-to "{assigned_to}" '
        f'--area "{area_path}" '
        f'--organization "{organization}" '
        f'--project "{project}"'
    )

    if (open):
        command += " --open"

    process = subprocess.run(command, capture_output=True,
                             text=True,
                             shell=True, check=True)

    print(process.stderr)
    try:
        data = json.loads(process.stdout)
        print(process.stdout)
        print_tickets([data])
    except:
        print("Failed to parse JSON. Response was:")
        print(process.stdout)
        return None


# Stolen from smartdok-utils
# Maybe it will get moved there later anyways
def print_tickets(items):
    rows = [format_work_item_row(item) for item in items]
    print_table(rows)


def print_table(rows: list[list[tuple[str, str]]]):
    widths = find_widths(rows)
    for row in rows:
        for (i, (color, text)) in enumerate(row):
            content = text.rjust(
                widths[i]) if i == 0 else text.ljust(widths[i])
            print(f'{color}{content}{Style.RESET_ALL}', end=' ')
        print('')


def find_widths(rows: list[list[tuple[str, str]]]) -> list[int]:
    widths = []
    for row in rows:
        for (i, (_, text)) in enumerate(row):
            l = len(text)
            if len(widths) <= i:
                widths.append(l)
            else:
                widths[i] = min([max([widths[i], l]), 80])

    return widths


def format_work_item_row(item: dict) -> list[tuple[str, str]]:
    if item['fields'] is None:
        return [(Fore.RED, f'{item["id"]}')]

    title = item['fields']['System.Title']
    item_type = item['fields']['System.WorkItemType']
    state = item['fields']['System.State']
    assigned_to = item['fields'].get('System.AssignedTo')
    assigned_to = assigned_to['displayName'] if assigned_to is not None else ''

    ident = f"{item_type} {item['id']}"

    return [
        (color_for_type(item_type), ident),
        (Fore.WHITE, title),
        (Fore.GREEN, state),
        (Fore.MAGENTA, assigned_to),
    ]


def color_for_type(item_type: str) -> str:
    if item_type == 'Bug':
        return Fore.RED
    elif item_type == 'User Story':
        return Fore.BLUE
    elif item_type == 'Task':
        return Fore.YELLOW
    elif item_type == 'Chore':
        return Fore.MAGENTA
    else:
        return Fore.WHITE


if __name__ == "__main__":
    main()
